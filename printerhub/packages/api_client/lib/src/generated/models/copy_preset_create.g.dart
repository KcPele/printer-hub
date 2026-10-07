// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_preset_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CopyPresetCreate _$CopyPresetCreateFromJson(Map<String, dynamic> json) =>
    CopyPresetCreate(
      name: json['name'] as String,
      type: json['type'] as String,
      printerId: json['printer_id'] as String?,
      settings: json['settings'] == null
          ? null
          : CopySettingsInput.fromJson(
              json['settings'] as Map<String, dynamic>,
            ),
      isDefault: json['is_default'] as bool? ?? false,
      scope: json['scope'] == null
          ? PresetScope.personal
          : PresetScope.fromJson(json['scope'] as String),
    );

Map<String, dynamic> _$CopyPresetCreateToJson(CopyPresetCreate instance) =>
    <String, dynamic>{
      'is_default': instance.isDefault,
      'name': instance.name,
      'printer_id': ?instance.printerId,
      'scope': instance.scope.toJson(),
      'settings': ?instance.settings?.toJson(),
      'type': instance.type,
    };
