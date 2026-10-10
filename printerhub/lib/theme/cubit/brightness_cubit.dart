import 'package:bloc/bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences_repository/preferences_repository.dart';

/// Holds whether the app is shown light, dark, or as the phone is.
///
/// It is kept on this phone and not with the account: a phone used at
/// night and a tablet on a desk are not the same.
class BrightnessCubit extends Cubit<ThemeMode> {
  new({required this._preferencesRepository})
    : super(_named(_preferencesRepository.brightnessName));

  final PreferencesRepository _preferencesRepository;

  /// Until someone chooses, the app looks as the phone does.
  static ThemeMode _named(String? name) => ThemeMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => ThemeMode.system,
  );

  /// Applies [mode] at once, then saves it.
  Future<void> select(ThemeMode mode) async {
    if (mode == state) return;
    emit(mode);
    await _preferencesRepository.saveBrightnessName(mode.name);
  }
}
