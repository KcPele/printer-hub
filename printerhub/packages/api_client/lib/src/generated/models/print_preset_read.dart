// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'preset_read.dart';
import 'preset_scope.dart';
import 'print_settings_output.dart';

part 'print_preset_read.g.dart';

@JsonSerializable()
class PrintPresetRead {
  const PrintPresetRead({
    required this.createdAt,
    required this.id,
    required this.isDefault,
    required this.name,
    required this.organizationId,
    required this.ownerUserId,
    required this.printerId,
    required this.scope,
    required this.settings,
    required this.type,
    required this.updatedAt,
  });

  factory PrintPresetRead.fromJson(Map<String, Object?> json) =>
      _$PrintPresetReadFromJson(json);

  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final String id;
  @JsonKey(name: 'is_default')
  final bool isDefault;
  final String name;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'owner_user_id')
  final String? ownerUserId;
  @JsonKey(name: 'printer_id')
  final String? printerId;
  final PresetScope scope;
  final PrintSettingsOutput settings;
  final String type;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, Object?> toJson() => _$PrintPresetReadToJson(this);
}
