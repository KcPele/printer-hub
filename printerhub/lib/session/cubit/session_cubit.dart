import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:preferences_repository/preferences_repository.dart';

part 'session_state.dart';

/// Knows who is signed in and which workspace is in use. The router sends
/// people to the right screen from its state.
class SessionCubit extends Cubit<SessionState> {
  /// [keptOrganizations] is the workspace list from the last launch, read
  /// before the first frame so a returning user goes straight to Home.
  new({
    required AuthRepository authRepository,
    required this._organizationsRepository,
    required this._preferencesRepository,
    List<Organization>? keptOrganizations,
  }) : _authRepository = authRepository,
       super(const SessionState.signedOut()) {
    final user = authRepository.user;
    if (user != null) {
      emit(
        keptOrganizations == null || keptOrganizations.isEmpty
            ? SessionState(stage: SessionStage.loading, user: user)
            : _withOrganizations(user, keptOrganizations),
      );
    }
    _statuses = authRepository.statusChanges.listen(_onStatus);
  }

  final AuthRepository _authRepository;
  final OrganizationsRepository _organizationsRepository;
  final PreferencesRepository _preferencesRepository;
  late final StreamSubscription<AuthStatus> _statuses;

  /// Brings a restored session up to date. Call once after launch.
  Future<void> refresh() async {
    if (state.user == null) return;
    await _authRepository.refresh();
    await loadWorkspaces();
  }

  /// Fetches the user's workspaces and picks the one to use.
  Future<void> loadWorkspaces() async {
    final user = state.user;
    if (user == null) return;
    try {
      final organizations = await _organizationsRepository.list();
      // The user may have signed out while the request was out.
      if (state.user == null) return;
      emit(_withOrganizations(state.user!, organizations));
    } on ApiException catch (error) {
      if (state.stage != SessionStage.loading) return;
      emit(SessionState(stage: SessionStage.failed, user: user, error: error));
    }
  }

  /// Tries again after [SessionStage.failed].
  Future<void> retry() async {
    emit(SessionState(stage: SessionStage.loading, user: state.user));
    await loadWorkspaces();
  }

  /// Creates a workspace and starts using it.
  Future<void> createWorkspace(String name) async {
    final created = await _organizationsRepository.create(name);
    emit(
      SessionState(
        stage: SessionStage.ready,
        user: state.user,
        organizations: [...state.organizations, created],
        organization: created,
      ),
    );
    await _remember(created);
  }

  /// Switches to another of the user's workspaces.
  Future<void> selectWorkspace(Organization organization) async {
    emit(
      SessionState(
        stage: SessionStage.ready,
        user: state.user,
        organizations: state.organizations,
        organization: organization,
      ),
    );
    await _remember(organization);
  }

  Future<void> signOut() => _authRepository.signOut();

  @override
  Future<void> close() async {
    await _statuses.cancel();
    await super.close();
  }

  Future<void> _onStatus(AuthStatus status) async {
    switch (status) {
      case SignedIn(:final user):
        if (state.user == null) {
          emit(SessionState(stage: SessionStage.loading, user: user));
          await loadWorkspaces();
        } else {
          emit(
            SessionState(
              stage: state.stage,
              user: user,
              organizations: state.organizations,
              organization: state.organization,
              error: state.error,
            ),
          );
        }
      case SignedOut() || AuthUnknown():
        emit(const SessionState.signedOut());
        await _organizationsRepository.clear();
        await _preferencesRepository.saveActiveOrganizationId(null);
    }
  }

  /// The workspace last used on this device, else the one last used on any
  /// device, else the first.
  SessionState _withOrganizations(User user, List<Organization> all) {
    if (all.isEmpty) {
      return SessionState(stage: SessionStage.needsWorkspace, user: user);
    }
    Organization? byId(String? id) {
      return all.where((organization) => organization.id == id).firstOrNull;
    }

    return SessionState(
      stage: SessionStage.ready,
      user: user,
      organizations: all,
      organization:
          byId(state.organization?.id) ??
          byId(_preferencesRepository.activeOrganizationId) ??
          byId(user.defaultOrganizationId) ??
          all.first,
    );
  }

  Future<void> _remember(Organization organization) async {
    await _preferencesRepository.saveActiveOrganizationId(organization.id);
    try {
      await _authRepository.savePreferences(
        defaultOrganizationId: organization.id,
      );
    } on ApiException {
      // The choice is kept on this device. It reaches the account next time.
    }
  }
}
