import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:jobs_repository/jobs_repository.dart';

class PresetsState extends Equatable {
  const new({
    this.loaded = false,
    this.presets = const [],
    this.busy = false,
    this.error,
  });

  /// False until the presets have been read once.
  final bool loaded;

  /// The saved ways of printing that can be used on this printer, by name.
  final List<Preset> presets;

  /// True while a preset is being saved, changed, or deleted.
  final bool busy;

  /// Why the last change could not be made. Pass it to `errorMessage`.
  final ApiException? error;

  @override
  List<Object?> get props => [loaded, presets, busy, error];
}

/// The saved ways of printing on one printer: the person's own and the
/// ones their workspace shares.
class PresetsCubit extends Cubit<PresetsState> {
  new({
    required this._presetsRepository,
    required this._organizationId,
    required this._printerId,
  }) : super(const PresetsState());

  final PresetsRepository _presetsRepository;
  final String _organizationId;
  final String _printerId;

  /// The preset a print starts from: the person's own before the
  /// workspace's, and one for this printer before one for any.
  Preset? get standard {
    final defaults = [
      for (final preset in state.presets)
        if (preset.isDefault) preset,
    ];
    int rank(Preset preset) =>
        (preset.shared ? 2 : 0) + (preset.printerId == null ? 1 : 0);
    defaults.sort((a, b) => rank(a).compareTo(rank(b)));
    return defaults.firstOrNull;
  }

  /// Reads the presets. Printing does not depend on them, so a failure
  /// leaves the list as it was and says nothing.
  Future<void> load() async {
    try {
      final presets = await _list();
      if (!isClosed) emit(PresetsState(loaded: true, presets: presets));
    } on ApiException {
      if (!isClosed) emit(PresetsState(loaded: true, presets: state.presets));
    }
  }

  /// A preset as it is now, since a shared one may have been changed. Null
  /// when it has been deleted.
  Future<Preset?> fresh(Preset preset) async {
    try {
      return await _presetsRepository.get(
        organizationId: _organizationId,
        presetId: preset.id,
      );
    } on ApiUnreachable {
      return preset;
    } on ApiProblem {
      emit(
        PresetsState(
          loaded: true,
          presets: [
            for (final other in state.presets)
              if (other.id != preset.id) other,
          ],
        ),
      );
      return null;
    }
  }

  /// Saves [choices] under [name], for this printer.
  Future<void> save({
    required String name,
    required PrintChoices choices,
    bool isDefault = false,
    bool shared = false,
  }) {
    return _change(
      () => _presetsRepository.savePrint(
        organizationId: _organizationId,
        name: name,
        choices: choices,
        printerId: _printerId,
        isDefault: isDefault,
        shared: shared,
      ),
    );
  }

  Future<void> rename(Preset preset, String name) {
    return _change(
      () => _presetsRepository.update(
        organizationId: _organizationId,
        presetId: preset.id,
        name: name,
      ),
    );
  }

  /// Makes [preset] what a print starts from, or stops it being so.
  Future<void> setStandard(Preset preset, {required bool standard}) {
    return _change(
      () => _presetsRepository.update(
        organizationId: _organizationId,
        presetId: preset.id,
        isDefault: standard,
      ),
    );
  }

  /// Puts [choices] in place of what [preset] held.
  Future<void> replace(Preset preset, PrintChoices choices) {
    return _change(
      () => _presetsRepository.update(
        organizationId: _organizationId,
        presetId: preset.id,
        choices: choices,
      ),
    );
  }

  Future<void> remove(Preset preset) {
    return _change(
      () => _presetsRepository.delete(
        organizationId: _organizationId,
        presetId: preset.id,
      ),
    );
  }

  /// Makes one change, then reads the list again: a new default takes the
  /// place of the old one on the backend.
  Future<void> _change(Future<void> Function() change) async {
    if (state.busy) return;
    emit(PresetsState(loaded: true, presets: state.presets, busy: true));
    try {
      await change();
      emit(PresetsState(loaded: true, presets: await _list()));
    } on ApiException catch (error) {
      emit(PresetsState(loaded: true, presets: state.presets, error: error));
    }
  }

  Future<List<Preset>> _list() async {
    final presets = await _presetsRepository.list(
      organizationId: _organizationId,
      printerId: _printerId,
    );
    return [
      for (final preset in presets)
        if (preset.print != null) preset,
    ];
  }
}
