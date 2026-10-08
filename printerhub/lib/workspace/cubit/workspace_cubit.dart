import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:organizations_repository/organizations_repository.dart';

enum WorkspaceStatus { loading, ready, failed }

/// What was last done to the workspace, for the screen to answer.
enum WorkspaceDone { saved, left, deleted }

class WorkspaceState extends Equatable {
  const new({
    this.status = WorkspaceStatus.loading,
    this.workspace,
    this.error,
    this.busy = false,
    this.done,
  });

  final WorkspaceStatus status;
  final Workspace? workspace;

  /// Why the workspace could not be read or changed. Pass it to
  /// `errorMessage`.
  final ApiException? error;

  /// True while a change is being made.
  final bool busy;
  final WorkspaceDone? done;

  @override
  List<Object?> get props => [status, workspace, error, busy, done];
}

/// One workspace: its name and rules, and leaving or deleting it.
class WorkspaceCubit extends Cubit<WorkspaceState> {
  new({
    required this._organizationsRepository,
    required this._organizationId,
    required this._userId,
  }) : super(const WorkspaceState());

  final OrganizationsRepository _organizationsRepository;
  final String _organizationId;
  final String _userId;

  Future<void> load() async {
    emit(const WorkspaceState());
    try {
      final workspace = await _organizationsRepository.details(_organizationId);
      if (isClosed) return;
      emit(WorkspaceState(status: WorkspaceStatus.ready, workspace: workspace));
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(WorkspaceState(status: WorkspaceStatus.failed, error: error));
    }
  }

  /// Saves the name and the rules.
  Future<void> save({required String name, required WorkspacePolicy policy}) {
    return _change(
      WorkspaceDone.saved,
      () => _organizationsRepository.update(
        _organizationId,
        name: name,
        policy: policy,
      ),
    );
  }

  /// Takes the signed-in person out of the workspace.
  Future<void> leave() {
    return _change(WorkspaceDone.left, () async {
      await _organizationsRepository.leave(
        organizationId: _organizationId,
        userId: _userId,
      );
      return null;
    });
  }

  /// Deletes the workspace for everyone.
  Future<void> delete() {
    return _change(WorkspaceDone.deleted, () async {
      await _organizationsRepository.delete(_organizationId);
      return null;
    });
  }

  Future<void> _change(
    WorkspaceDone done,
    Future<Workspace?> Function() change,
  ) async {
    final workspace = state.workspace;
    if (workspace == null || state.busy) return;
    emit(
      WorkspaceState(
        status: WorkspaceStatus.ready,
        workspace: workspace,
        busy: true,
      ),
    );
    try {
      final changed = await change();
      if (isClosed) return;
      emit(
        WorkspaceState(
          status: WorkspaceStatus.ready,
          workspace: changed ?? workspace,
          done: done,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(
        WorkspaceState(
          status: WorkspaceStatus.ready,
          workspace: workspace,
          error: error,
        ),
      );
    }
  }
}
