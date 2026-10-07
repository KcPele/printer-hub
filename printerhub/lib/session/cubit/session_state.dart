part of 'session_cubit.dart';

/// How far the app is from being usable.
enum SessionStage {
  /// Nobody is signed in.
  signedOut,

  /// Signed in. The user's workspaces are being fetched.
  loading,

  /// The workspaces could not be fetched.
  failed,

  /// Signed in, with no workspace yet.
  needsWorkspace,

  /// Signed in, with a workspace in use.
  ready,
}

class SessionState extends Equatable {
  const new({
    required this.stage,
    this.user,
    this.organizations = const [],
    this.organization,
    this.error,
  });

  const new signedOut() : this(stage: SessionStage.signedOut);

  final SessionStage stage;
  final User? user;

  /// Every workspace the user belongs to.
  final List<Organization> organizations;

  /// The workspace in use.
  final Organization? organization;

  /// Why loading failed. Pass it to `errorMessage`.
  final ApiException? error;

  @override
  List<Object?> get props => [stage, user, organizations, organization, error];
}
