import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:organizations_repository/organizations_repository.dart';

enum MembersStatus { loading, ready, failed }

class MembersState extends Equatable {
  const new({
    this.status = MembersStatus.loading,
    this.members = const [],
    this.invitations = const [],
    this.error,
    this.busy = false,
    this.sent,
  });

  final MembersStatus status;

  /// The people in the workspace, by name.
  final List<Member> members;

  /// The invitations nobody has taken up yet. Empty for someone who may
  /// not see them.
  final List<Invitation> invitations;

  /// Why the people could not be read, or a change could not be made. Pass
  /// it to `errorMessage`.
  final ApiException? error;
  final bool busy;

  /// The invitation just made, with the code to pass on.
  final Invitation? sent;

  @override
  List<Object?> get props => [status, members, invitations, error, busy, sent];
}

/// The people in a workspace and the invitations it has sent.
class MembersCubit extends Cubit<MembersState> {
  new({
    required this._organizationsRepository,
    required this._organizationId,
    required this._canManage,
  }) : super(const MembersState());

  final OrganizationsRepository _organizationsRepository;
  final String _organizationId;

  /// Only someone who manages the workspace may see its invitations.
  final bool _canManage;

  Future<void> load() async {
    emit(const MembersState());
    try {
      final read = await _read();
      if (isClosed) return;
      emit(
        MembersState(
          status: MembersStatus.ready,
          members: read.members,
          invitations: read.invitations,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(MembersState(status: MembersStatus.failed, error: error));
    }
  }

  Future<({List<Member> members, List<Invitation> invitations})> _read() async {
    final members = await _organizationsRepository.members(_organizationId);
    final invitations = _canManage
        ? await _organizationsRepository.invitations(_organizationId)
        : const <Invitation>[];
    return (
      members: [...members]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      invitations: invitations,
    );
  }

  /// Invites someone by email. The state then carries the invitation with
  /// its code.
  Future<void> invite({required String email, required String role}) async {
    Invitation? sent;
    await _change(() async {
      sent = await _organizationsRepository.invite(
        organizationId: _organizationId,
        email: email,
        role: role,
      );
    });
    final made = sent;
    if (made != null && !isClosed && state.error == null) {
      emit(
        MembersState(
          status: MembersStatus.ready,
          members: state.members,
          invitations: state.invitations,
          sent: made,
        ),
      );
    }
  }

  Future<void> revoke(Invitation invitation) {
    return _change(
      () => _organizationsRepository.revokeInvitation(
        organizationId: _organizationId,
        invitationId: invitation.id,
      ),
    );
  }

  Future<void> changeRole(Member member, String role) {
    return _change(
      () => _organizationsRepository.changeRole(
        organizationId: _organizationId,
        userId: member.userId,
        role: role,
      ),
    );
  }

  Future<void> remove(Member member) {
    return _change(
      () => _organizationsRepository.removeMember(
        organizationId: _organizationId,
        userId: member.userId,
      ),
    );
  }

  /// Makes one change, then reads everything again.
  Future<void> _change(Future<void> Function() change) async {
    if (state.busy || state.status != MembersStatus.ready) return;
    emit(
      MembersState(
        status: MembersStatus.ready,
        members: state.members,
        invitations: state.invitations,
        busy: true,
      ),
    );
    try {
      await change();
      final read = await _read();
      if (isClosed) return;
      emit(
        MembersState(
          status: MembersStatus.ready,
          members: read.members,
          invitations: read.invitations,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(
        MembersState(
          status: MembersStatus.ready,
          members: state.members,
          invitations: state.invitations,
          error: error,
        ),
      );
    }
  }
}
