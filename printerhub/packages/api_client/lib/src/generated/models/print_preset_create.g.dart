// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'print_preset_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrintPresetCreate _$PrintPresetCreateFromJson(Map<String, dynamic> json) =>
    PrintPresetCreate(
      name: json['name'] as String,
      type: json['type'] as String,
      printerId: json['printer_id'] as String?,
      settings: json['settings'] == null
          ? null
          : PrintSettingsInput.fromJson(
              json['settings'] as Map<String, dynamic>,
            ),
      isDefault: json['is_default'] as bool? ?? false,
      scope: json['scope'] == null
          ? PresetScope.personal
          : PresetScope.fromJson(json['scope'] as String),
    );

Map<String, dynamic> _$PrintPresetCreateToJson(PrintPresetCreate instance) =>
    <String, dynamic>{
      'is_default': instance.isDefault,
      'name': instance.name,
      'printer_id': instance.printerId,
      'scope': instance.scope,
      'settings': instance.settings,
      'type': instance.type,
    };
