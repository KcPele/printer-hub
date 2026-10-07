// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preset_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PresetCreateToJson(PresetCreate instance) =>
    <String, dynamic>{};

PresetCreateCopyPresetCreate _$PresetCreateCopyPresetCreateFromJson(
  Map<String, dynamic> json,
) => PresetCreateCopyPresetCreate(
  isDefault: json['is_default'] as bool,
  name: json['name'] as String,
  printerId: json['printer_id'] as String?,
  scope: PresetScope.fromJson(json['scope'] as String),
  settings: json['settings'] == null
      ? null
      : CopySettingsInput.fromJson(json['settings'] as Map<String, dynamic>),
  type: json['type'] as String,
);

Map<String, dynamic> _$PresetCreateCopyPresetCreateToJson(
  PresetCreateCopyPresetCreate instance,
) => <String, dynamic>{
  'is_default': instance.isDefault,
  'name': instance.name,
  'printer_id': ?instance.printerId,
  'scope': instance.scope.toJson(),
  'settings': ?instance.settings?.toJson(),
  'type': instance.type,
};

PresetCreatePrintPresetCreate _$PresetCreatePrintPresetCreateFromJson(
  Map<String, dynamic> json,
) => PresetCreatePrintPresetCreate(
  isDefault: json['is_default'] as bool,
  name: json['name'] as String,
  printerId: json['printer_id'] as String?,
  scope: PresetScope.fromJson(json['scope'] as String),
  settings: json['settings'] == null
      ? null
      : PrintSettingsInput.fromJson(json['settings'] as Map<String, dynamic>),
  type: json['type'] as String,
);

Map<String, dynamic> _$PresetCreatePrintPresetCreateToJson(
  PresetCreatePrintPresetCreate instance,
) => <String, dynamic>{
  'is_default': instance.isDefault,
  'name': instance.name,
  'printer_id': ?instance.printerId,
  'scope': instance.scope.toJson(),
  'settings': ?instance.settings?.toJson(),
  'type': instance.type,
};

PresetCreateScanPresetCreate _$PresetCreateScanPresetCreateFromJson(
  Map<String, dynamic> json,
) => PresetCreateScanPresetCreate(
  isDefault: json['is_default'] as bool,
  name: json['name'] as String,
  printerId: json['printer_id'] as String?,
  scope: PresetScope.fromJson(json['scope'] as String),
  settings: json['settings'] == null
      ? null
      : ScanSettingsInput.fromJson(json['settings'] as Map<String, dynamic>),
  type: json['type'] as String,
);

Map<String, dynamic> _$PresetCreateScanPresetCreateToJson(
  PresetCreateScanPresetCreate instance,
) => <String, dynamic>{
  'is_default': instance.isDefault,
  'name': instance.name,
  'printer_id': ?instance.printerId,
  'scope': instance.scope.toJson(),
  'settings': ?instance.settings?.toJson(),
  'type': instance.type,
};
