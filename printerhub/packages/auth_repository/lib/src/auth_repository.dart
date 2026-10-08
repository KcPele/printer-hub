import 'dart:async';
import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:auth_repository/src/auth_status.dart';
import 'package:auth_repository/src/models.dart';
import 'package:local_store/local_store.dart';

/// Signs people in and out, and knows who is signed in.
///
/// Every method that talks to the API throws an [ApiException] on failure.
class AuthRepository {
  /// `describePhone` reads what this phone is. With it, the phone is
  /// registered with the account each time a session starts or resumes.
  new({required this._client, required this._store, this._describePhone}) {
    _sessionEnded = _client.sessionEnded.listen((_) => _forget());
  }

  static const String _userKey = 'session.user';

  /// Made once per install and kept through sign-out, so the backend knows
  /// the same phone when someone signs in again.
  static const String _installationKey = 'installation.id';

  final PrinterHubClient _client;
  final SecureStore _store;
  final Future<PhoneDetails> Function()? _describePhone;
  // Synchronous, so a listener has the new status before the call that
  // caused it returns.
  final _statuses = StreamController<AuthStatus>.broadcast(sync: true);
  late final StreamSubscription<void> _sessionEnded;

  AuthStatus _status = const AuthUnknown();
  UserRead? _account;

  /// The status now.
  AuthStatus get status => _status;

  /// Every change of status after this call.
  Stream<AuthStatus> get statusChanges => _statuses.stream;

  /// The signed-in user, or null.
  User? get user => switch (_status) {
    SignedIn(:final user) => user,
    _ => null,
  };

  /// Reads the stored session at launch, without using the network.
  ///
  /// The user kept from the last launch is signed in at once, so the app
  /// opens straight away and works offline. Call [refresh] afterwards.
  Future<void> restore() async {
    final cached = await _readCachedAccount();
    if (cached == null || !await _client.hasSession) {
      await _forget();
      return;
    }
    _setAccount(cached);
  }

  /// Fetches the account again, picking up changes made elsewhere.
  ///
  /// Signs out when the API no longer accepts the session. Any other
  /// failure, such as being offline, leaves the kept user in place.
  Future<void> refresh() async {
    if (_account == null) return;
    try {
      await _remember(await apiCall(() => _client.api.users.getMe()));
      await registerDevice();
    } on ApiProblem catch (problem) {
      if (problem.status == 401) await _forget();
    } on ApiUnreachable {
      // Offline. The kept user stands.
    }
  }

  Future<User> signIn({required String email, required String password}) {
    return _startSession(
      () => _client.api.auth.login(
        body: LoginRequest(email: email, password: password),
      ),
    );
  }

  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _startSession(
      () => _client.api.auth.register(
        body: RegisterRequest(name: name, email: email, password: password),
      ),
    );
  }

  /// Signs out here and revokes the session on the server when it can be
  /// reached. Signing out never fails.
  Future<void> signOut() async {
    try {
      await apiCall(() => _client.api.auth.logout());
    } on ApiException {
      // The session is forgotten on this device either way.
    }
    await _forget();
  }

  /// Confirms the email address with the 6-digit code that was emailed.
  Future<User> verifyEmail(String code) async {
    final account = await apiCall(
      () => _client.api.auth.verifyEmail(body: EmailVerifyRequest(code: code)),
    );
    return await _remember(account);
  }

  Future<void> resendVerification() {
    return apiCall(() => _client.api.auth.resendVerification());
  }

  /// Emails a reset code. The API answers the same way whether or not the
  /// address has an account.
  Future<void> requestPasswordReset(String email) {
    return apiCall(
      () => _client.api.auth.forgotPassword(
        body: PasswordForgotRequest(email: email),
      ),
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return apiCall(
      () => _client.api.auth.resetPassword(
        body: PasswordResetRequest(
          email: email,
          code: code,
          newPassword: newPassword,
        ),
      ),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return apiCall(
      () => _client.api.auth.changePassword(
        body: ChangePasswordRequest(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      ),
    );
  }

  Future<User> updateName(String name) async {
    final account = await apiCall(
      () => _client.api.users.updateMe(body: UserUpdate(name: name)),
    );
    return await _remember(account);
  }

  /// Saves preferences with the account, so they follow the user to another
  /// device. Anything not given keeps its value.
  Future<User> savePreferences({
    String? appTheme,
    String? defaultOrganizationId,
  }) async {
    final current = _account!.preferences;
    final account = await apiCall(
      () => _client.api.users.updateMe(
        body: UserUpdate(
          // The API replaces preferences as a whole, so the ones that are
          // not changing are sent back as they are.
          preferences: UserPreferencesInput(
            appTheme: UserPreferencesInputAppTheme.fromJson(
              appTheme ?? current.appTheme.json ?? 'mint',
            ),
            theme: UserPreferencesInputTheme.fromJson(
              current.theme.json ?? 'system',
            ),
            defaultOrganizationId:
                defaultOrganizationId ?? current.defaultOrganizationId,
            defaultPrinterId: current.defaultPrinterId,
            mutedNotificationTypes: current.mutedNotificationTypes,
          ),
        ),
      ),
    );
    return await _remember(account);
  }

  /// This install's identifier, made the first time it is asked for.
  Future<String> installationId() async {
    final kept = await _store.read(_installationKey);
    if (kept != null) return kept;
    final made = newIdempotencyKey();
    await _store.write(_installationKey, made);
    return made;
  }

  /// Tells the backend which phone this session is on, and with
  /// [pushToken] where to send its notifications.
  ///
  /// Never throws: a session works without it, and it is tried again the
  /// next time the app opens. Null when it could not be done.
  Future<UserDevice?> registerDevice({String? pushToken}) async {
    final describe = _describePhone;
    if (describe == null) return null;
    try {
      final phone = await describe();
      final id = await installationId();
      final device = await apiCall(
        () => _client.api.devices.registerDevice(
          body: DeviceRegister(
            installationId: id,
            platform: DevicePlatform.fromJson(phone.platform),
            name: phone.name,
            model: phone.model,
            osVersion: phone.osVersion,
            appVersion: phone.appVersion,
            pushProvider: pushToken == null ? null : PushProviderName.fcm,
            pushToken: pushToken,
          ),
        ),
      );
      return UserDevice.fromApi(device, installationId: id);
    } on ApiException {
      return null;
    }
  }

  /// Every phone and tablet the account has been used on.
  Future<List<UserDevice>> devices() async {
    final id = await installationId();
    final devices = await apiCall(() => _client.api.devices.listDevices());
    return [
      for (final device in devices)
        UserDevice.fromApi(device, installationId: id),
    ];
  }

  /// Forgets a device: it stops receiving notifications.
  Future<void> removeDevice(String id) {
    return apiCall(() => _client.api.devices.deleteDevice(deviceId: id));
  }

  Future<List<UserSession>> sessions() async {
    final sessions = await apiCall(() => _client.api.auth.listSessions());
    return sessions.map(UserSession.fromApi).toList();
  }

  Future<void> revokeSession(String id) {
    return apiCall(() => _client.api.auth.revokeSession(sessionId: id));
  }

  /// Deletes the account for good, then signs out.
  Future<void> deleteAccount({required String password}) async {
    await apiCall(
      () => _client.api.account.deleteAccount(
        body: AccountDeleteRequest(password: password),
      ),
    );
    await _forget();
  }

  Future<void> close() async {
    await _sessionEnded.cancel();
    await _statuses.close();
  }

  Future<User> _startSession(Future<AuthResponse> Function() request) async {
    final response = await apiCall(request);
    await _client.startSession(response.tokens);
    final user = await _remember(response.user);
    await registerDevice();
    return user;
  }

  Future<User> _remember(UserRead account) async {
    await _store.write(_userKey, jsonEncode(account.toJson()));
    return _setAccount(account);
  }

  User _setAccount(UserRead account) {
    _account = account;
    final user = User.fromApi(account);
    _emit(SignedIn(user));
    return user;
  }

  Future<void> _forget() async {
    _account = null;
    await _client.endSession();
    await _store.delete(_userKey);
    _emit(const SignedOut());
  }

  Future<UserRead?> _readCachedAccount() async {
    final json = await _store.read(_userKey);
    if (json == null) return null;
    try {
      return UserRead.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object {
      // Written by an older version of the app. Sign in again.
      return null;
    }
  }

  void _emit(AuthStatus status) {
    if (status == _status) return;
    _status = status;
    _statuses.add(status);
  }
}
