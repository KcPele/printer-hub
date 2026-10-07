// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preset_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PresetReadToJson(PresetRead instance) =>
    <String, dynamic>{};

PresetReadCopyPresetRead _$PresetReadCopyPresetReadFromJson(
  Map<String, dynamic> json,
) => PresetReadCopyPresetRead(
  createdAt: DateTime.parse(json['created_at'] as String),
  id: json['id'] as String,
  isDefault: json['is_default'] as bool,
  name: json['name'] as String,
  organizationId: json['organization_id'] as String,
  ownerUserId: json['owner_user_id'] as String?,
  printerId: json['printer_id'] as String?,
  scope: PresetScope.fromJson(json['scope'] as String),
  settings: CopySettingsOutput.fromJson(
    json['settings'] as Map<String, dynamic>,
  ),
  type: json['type'] as String,
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$PresetReadCopyPresetReadToJson(
  PresetReadCopyPresetRead instance,
) => <String, dynamic>{
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

PresetReadPrintPresetRead _$PresetReadPrintPresetReadFromJson(
  Map<String, dynamic> json,
) => PresetReadPrintPresetRead(
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

Map<String, dynamic> _$PresetReadPrintPresetReadToJson(
  PresetReadPrintPresetRead instance,
) => <String, dynamic>{
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

PresetReadScanPresetRead _$PresetReadScanPresetReadFromJson(
  Map<String, dynamic> json,
) => PresetReadScanPresetRead(
  createdAt: DateTime.parse(json['created_at'] as String),
  id: json['id'] as String,
  isDefault: json['is_default'] as bool,
  name: json['name'] as String,
  organizationId: json['organization_id'] as String,
  ownerUserId: json['owner_user_id'] as String?,
  printerId: json['printer_id'] as String?,
  scope: PresetScope.fromJson(json['scope'] as String),
  settings: ScanSettingsOutput.fromJson(
    json['settings'] as Map<String, dynamic>,
  ),
  type: json['type'] as String,
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$PresetReadScanPresetReadToJson(
  PresetReadScanPresetRead instance,
) => <String, dynamic>{
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
