// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'preset_create.dart';
import 'preset_scope.dart';
import 'scan_settings_input.dart';

part 'scan_preset_create.g.dart';

@JsonSerializable()
class ScanPresetCreate {
  const ScanPresetCreate({
    required this.name,
    required this.type,
    this.printerId,
    this.settings,
    this.isDefault = false,
    this.scope = PresetScope.personal,
  });

  factory ScanPresetCreate.fromJson(Map<String, Object?> json) =>
      _$ScanPresetCreateFromJson(json);

  @JsonKey(name: 'is_default')
  final bool isDefault;
  final String name;

  /// Limit the preset to one printer; omit for all printers
  @JsonKey(name: 'printer_id')
  final String? printerId;
  final PresetScope scope;
  final ScanSettingsInput? settings;
  final String type;

  Map<String, Object?> toJson() => _$ScanPresetCreateToJson(this);
}
