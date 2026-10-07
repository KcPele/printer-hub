import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:preferences_repository/preferences_repository.dart';

/// Holds the theme the user has chosen.
///
/// The choice is kept on the device, and with the account when someone is
/// signed in. A device that has no choice of its own takes the account's
/// when its owner signs in.
class ThemeCubit extends Cubit<AppThemeId> {
  new({
    required PreferencesRepository preferencesRepository,
    AuthRepository? authRepository,
  }) : _preferencesRepository = preferencesRepository,
       _authRepository = authRepository,
       super(AppThemeId.fromName(preferencesRepository.themeName)) {
    _statuses = authRepository?.statusChanges.listen(_onStatus);
  }

  final PreferencesRepository _preferencesRepository;
  final AuthRepository? _authRepository;
  StreamSubscription<AuthStatus>? _statuses;

  /// Applies [theme] at once, then saves it.
  Future<void> select(AppThemeId theme) async {
    if (theme == state) return;
    emit(theme);
    await _preferencesRepository.saveThemeName(theme.name);

    if (_authRepository?.user == null) return;
    try {
      await _authRepository!.savePreferences(appTheme: theme.name);
    } on ApiException {
      // Kept on this device. The account catches up on the next change.
    }
  }

  @override
  Future<void> close() async {
    await _statuses?.cancel();
    await super.close();
  }

  Future<void> _onStatus(AuthStatus status) async {
    if (status is! SignedIn || _preferencesRepository.themeName != null) {
      return;
    }
    final theme = AppThemeId.fromName(status.user.appTheme);
    emit(theme);
    await _preferencesRepository.saveThemeName(theme.name);
  }
}
