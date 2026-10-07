// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'preset_update.g.dart';

/// Fields left out are unchanged. `settings` replaces the stored settings as a whole.
@JsonSerializable()
class PresetUpdate {
  const PresetUpdate({this.isDefault, this.name, this.settings});

  factory PresetUpdate.fromJson(Map<String, Object?> json) =>
      _$PresetUpdateFromJson(json);

  @JsonKey(name: 'is_default')
  final bool? isDefault;
  final String? name;

  /// Validated against the preset's job type
  final dynamic settings;

  Map<String, Object?> toJson() => _$PresetUpdateToJson(this);
}
