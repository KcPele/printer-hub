// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'copy_settings_input.dart';
import 'preset_create.dart';
import 'preset_scope.dart';

part 'copy_preset_create.g.dart';

@JsonSerializable()
class CopyPresetCreate {
  const CopyPresetCreate({
    required this.name,
    required this.type,
    this.printerId,
    this.settings,
    this.isDefault = false,
    this.scope = PresetScope.personal,
  });

  factory CopyPresetCreate.fromJson(Map<String, Object?> json) =>
      _$CopyPresetCreateFromJson(json);

  @JsonKey(name: 'is_default')
  final bool isDefault;
  final String name;

  /// Limit the preset to one printer; omit for all printers
  @JsonKey(name: 'printer_id')
  final String? printerId;
  final PresetScope scope;
  final CopySettingsInput? settings;
  final String type;

  Map<String, Object?> toJson() => _$CopyPresetCreateToJson(this);
}
