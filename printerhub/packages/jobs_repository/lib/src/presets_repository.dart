import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';
import 'package:jobs_repository/src/models.dart';

/// Settings saved under a name, to use again.
class Preset extends Equatable {
  const new({
    required this.id,
    required this.name,
    required this.kind,
    this.shared = false,
    this.printerId,
    this.isDefault = false,
    this.print,
  });

  factory fromApi(PresetRead preset) {
    final json = preset.toJson();
    final kind = json['type'] as String? ?? 'print';
    final settings = json['settings'];
    return Preset(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: kind,
      shared: json['scope'] == 'organization',
      printerId: json['printer_id'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      print: kind == 'print' && settings is Map<String, dynamic>
          ? PrintChoices.fromJson(settings)
          : null,
    );
  }

  final String id;
  final String name;

  /// `print`, `scan`, or `copy`.
  final String kind;

  /// True for a preset the whole workspace has. Otherwise it is the
  /// signed-in person's own.
  final bool shared;

  /// The one printer it is for. Null when it is for any printer.
  final String? printerId;

  /// True when it is what a job starts from.
  final bool isDefault;

  /// How to print. Null for a scan or a copy preset.
  final PrintChoices? print;

  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    shared,
    printerId,
    isDefault,
    print,
  ];
}

/// The settings people saved to use again: their own, and the ones their
/// workspace shares.
class PresetsRepository {
  new({required this._client});

  final PrinterHubClient _client;

  /// The presets of one [kind] that can be used on [printerId]: the ones
  /// for that printer and the ones for any printer, by name.
  Future<List<Preset>> list({
    required String organizationId,
    String kind = 'print',
    String? printerId,
  }) async {
    final presets = await apiCall(
      () => _client.api.presets.listPresets(
        orgId: organizationId,
        type: JobType.fromJson(kind),
        printerId: printerId,
      ),
    );
    return presets.map(Preset.fromApi).toList();
  }

  /// One preset as it is now. Someone else may have changed a shared one
  /// since it was listed.
  Future<Preset> get({
    required String organizationId,
    required String presetId,
  }) async {
    return Preset.fromApi(
      await apiCall(
        () => _client.api.presets.getPreset(
          orgId: organizationId,
          presetId: presetId,
        ),
      ),
    );
  }

  /// Saves how to print under [name]. Which pages to print belongs to a
  /// document and is not kept.
  ///
  /// With [printerId] it is for that printer only. With [shared] the whole
  /// workspace has it, which takes an admin.
  Future<Preset> savePrint({
    required String organizationId,
    required String name,
    required PrintChoices choices,
    String? printerId,
    bool shared = false,
    bool isDefault = false,
  }) async {
    return Preset.fromApi(
      await apiCall(
        () => _client.api.presets.createPreset(
          orgId: organizationId,
          body: PresetCreatePrintPresetCreate(
            type: 'print',
            name: name,
            scope: shared ? PresetScope.organization : PresetScope.personal,
            printerId: printerId,
            isDefault: isDefault,
            settings: _kept(choices).toApi(),
          ),
        ),
      ),
    );
  }

  /// Changes a preset. What is left null stays as it is.
  Future<Preset> update({
    required String organizationId,
    required String presetId,
    String? name,
    PrintChoices? choices,
    bool? isDefault,
  }) async {
    return Preset.fromApi(
      await apiCall(
        () => _client.api.presets.updatePreset(
          orgId: organizationId,
          presetId: presetId,
          body: PresetUpdate(
            name: name,
            settings: choices == null ? null : _kept(choices).toApi().toJson(),
            isDefault: isDefault,
          ),
        ),
      ),
    );
  }

  Future<void> delete({
    required String organizationId,
    required String presetId,
  }) {
    return apiCall(
      () => _client.api.presets.deletePreset(
        orgId: organizationId,
        presetId: presetId,
      ),
    );
  }

  static PrintChoices _kept(PrintChoices choices) =>
      choices.copyWith(pageRanges: () => null);
}
