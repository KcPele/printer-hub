import 'package:app_ui/app_ui.dart';
import 'package:bloc/bloc.dart';
import 'package:preferences_repository/preferences_repository.dart';

/// Holds the theme the user has chosen and remembers it on the device.
class ThemeCubit extends Cubit<AppThemeId> {
  new({required PreferencesRepository preferencesRepository})
    : _preferencesRepository = preferencesRepository,
      super(AppThemeId.fromName(preferencesRepository.themeName));

  final PreferencesRepository _preferencesRepository;

  /// Applies [theme] at once, then saves it.
  Future<void> select(AppThemeId theme) async {
    if (theme == state) return;
    emit(theme);
    await _preferencesRepository.saveThemeName(theme.name);
  }
}
