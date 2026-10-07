import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:preferences_repository/preferences_repository.dart';

part 'welcome_state.dart';

/// Follows the user through the welcome screens and remembers, on the
/// device, that they have been seen.
class WelcomeCubit extends Cubit<WelcomeState> {
  new({required this._preferencesRepository}) : super(const WelcomeState());

  /// Three introductions, then the theme choice.
  static const int pageCount = 4;

  final PreferencesRepository _preferencesRepository;

  void pageChanged(int page) => emit(state.copyWith(page: page));

  /// Leaves the welcome screens. They are not shown again on this device.
  Future<void> finish() async {
    await _preferencesRepository.completeOnboarding();
    emit(state.copyWith(finished: true));
  }
}
