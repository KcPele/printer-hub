import 'package:bloc/bloc.dart';
import 'package:preferences_repository/preferences_repository.dart';

/// Holds how large the app's words are, as a percentage of their full
/// size. Full size is the largest: the choice only ever makes them
/// smaller, for someone who wants more on the screen.
///
/// It is kept on this phone, and works on top of the phone's own text
/// size, never in place of it.
class TextSizeCubit extends Cubit<int> {
  new({required this._preferencesRepository})
    : super(_offered(_preferencesRepository.textSizePercent));

  final PreferencesRepository _preferencesRepository;

  /// The sizes on offer, largest first.
  static const List<int> sizes = [100, 95, 90, 85];

  /// A size that was never chosen, or is no longer offered, is full size.
  static int _offered(int? percent) =>
      sizes.contains(percent) ? percent! : sizes.first;

  /// How much the words are scaled by: 1 at full size.
  double get factor => state / 100;

  /// Applies [percent] at once, then saves it.
  Future<void> select(int percent) async {
    if (percent == state || !sizes.contains(percent)) return;
    emit(percent);
    await _preferencesRepository.saveTextSizePercent(percent);
  }
}
