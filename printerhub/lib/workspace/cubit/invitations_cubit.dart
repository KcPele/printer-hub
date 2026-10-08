import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:organizations_repository/organizations_repository.dart';

enum InvitationsStatus { loading, ready, failed }

class InvitationsState extends Equatable {
  const new({
    this.status = InvitationsStatus.loading,
    this.invitations = const [],
    this.error,
    this.busy = false,
    this.joined,
  });

  final InvitationsStatus status;

  /// The invitations sent to the signed-in person's address.
  final List<ReceivedInvitation> invitations;

  /// Why the invitations could not be read, or one could not be taken up.
  /// Pass it to `errorMessage`.
  final ApiException? error;
  final bool busy;

  /// The workspace just joined.
  final Organization? joined;

  /// True when the invitations are kept back until the person's email
  /// address is verified. A code still works.
  bool get needsVerifiedEmail =>
      error is ApiProblem &&
      (error! as ApiProblem).code == 'auth.email_not_verified';

  @override
  List<Object?> get props => [status, invitations, error, busy, joined];
}

/// The invitations the signed-in person has been sent, and joining a
/// workspace by one of them or by a code.
class InvitationsCubit extends Cubit<InvitationsState> {
  new({required this._organizationsRepository})
    : super(const InvitationsState());

  final OrganizationsRepository _organizationsRepository;

  Future<void> load() async {
    emit(const InvitationsState());
    try {
      final invitations = await _organizationsRepository.received();
      if (isClosed) return;
      emit(
        InvitationsState(
          status: InvitationsStatus.ready,
          invitations: invitations,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(
        InvitationsState(
          // Without a verified address there is still a code to type.
          status: error is ApiProblem && error.code == 'auth.email_not_verified'
              ? InvitationsStatus.ready
              : InvitationsStatus.failed,
          error: error,
        ),
      );
    }
  }

  Future<void> accept(ReceivedInvitation invitation) {
    return _join(() => _organizationsRepository.accept(invitation.id));
  }

  /// Joins with the code from an invitation.
  Future<void> acceptCode(String code) {
    return _join(() => _organizationsRepository.acceptCode(code.trim()));
  }

  Future<void> _join(Future<Organization> Function() join) async {
    if (state.busy || state.status != InvitationsStatus.ready) return;
    final before = state;
    emit(
      InvitationsState(
        status: InvitationsStatus.ready,
        invitations: before.invitations,
        error: before.needsVerifiedEmail ? before.error : null,
        busy: true,
      ),
    );
    try {
      final joined = await join();
      if (isClosed) return;
      emit(
        InvitationsState(
          status: InvitationsStatus.ready,
          invitations: [
            for (final invitation in before.invitations)
              if (invitation.organizationId != joined.id) invitation,
          ],
          error: before.needsVerifiedEmail ? before.error : null,
          joined: joined,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(
        InvitationsState(
          status: InvitationsStatus.ready,
          invitations: before.invitations,
          error: error,
        ),
      );
    }
  }
}
