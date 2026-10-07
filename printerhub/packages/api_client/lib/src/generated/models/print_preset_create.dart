// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'preset_create.dart';
import 'preset_scope.dart';
import 'print_settings_input.dart';

part 'print_preset_create.g.dart';

@JsonSerializable()
class PrintPresetCreate {
  const PrintPresetCreate({
    required this.name,
    required this.type,
    this.printerId,
    this.settings,
    this.isDefault = false,
    this.scope = PresetScope.personal,
  });

  factory PrintPresetCreate.fromJson(Map<String, Object?> json) =>
      _$PrintPresetCreateFromJson(json);

  @JsonKey(name: 'is_default')
  final bool isDefault;
  final String name;

  /// Limit the preset to one printer; omit for all printers
  @JsonKey(name: 'printer_id')
  final String? printerId;
  final PresetScope scope;
  final PrintSettingsInput? settings;
  final String type;

  Map<String, Object?> toJson() => _$PrintPresetCreateToJson(this);
}
