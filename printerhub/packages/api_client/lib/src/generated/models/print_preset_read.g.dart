// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'print_preset_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrintPresetRead _$PrintPresetReadFromJson(Map<String, dynamic> json) =>
    PrintPresetRead(
      createdAt: DateTime.parse(json['created_at'] as String),
      id: json['id'] as String,
      isDefault: json['is_default'] as bool,
      name: json['name'] as String,
      organizationId: json['organization_id'] as String,
      ownerUserId: json['owner_user_id'] as String?,
      printerId: json['printer_id'] as String?,
      scope: PresetScope.fromJson(json['scope'] as String),
      settings: PrintSettingsOutput.fromJson(
        json['settings'] as Map<String, dynamic>,
      ),
      type: json['type'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$PrintPresetReadToJson(PrintPresetRead instance) =>
    <String, dynamic>{
      'created_at': instance.createdAt.toIso8601String(),
      'id': instance.id,
      'is_default': instance.isDefault,
      'name': instance.name,
      'organization_id': instance.organizationId,
      'owner_user_id': ?instance.ownerUserId,
      'printer_id': ?instance.printerId,
      'scope': instance.scope.toJson(),
      'settings': instance.settings.toJson(),
      'type': instance.type,
      'updated_at': instance.updatedAt.toIso8601String(),
    };
