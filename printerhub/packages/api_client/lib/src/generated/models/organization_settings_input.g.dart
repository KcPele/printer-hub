// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_settings_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganizationSettingsInput _$OrganizationSettingsInputFromJson(
  Map<String, dynamic> json,
) => OrganizationSettingsInput(
  documentStorageMode: json['document_storage_mode'] == null
      ? OrganizationSettingsInputDocumentStorageMode.cloudAllowed
      : OrganizationSettingsInputDocumentStorageMode.fromJson(
          json['document_storage_mode'] as String,
        ),
  colorPrintingRoles: (json['color_printing_roles'] as List<dynamic>?)
      ?.map((e) => Role.fromJson(e as String))
      .toList(),
  documentRetentionDays: (json['document_retention_days'] as num?)?.toInt(),
  maxCopiesPerJob: (json['max_copies_per_job'] as num?)?.toInt(),
);

Map<String, dynamic> _$OrganizationSettingsInputToJson(
  OrganizationSettingsInput instance,
) => <String, dynamic>{
  'color_printing_roles': instance.colorPrintingRoles,
  'document_retention_days': instance.documentRetentionDays,
  'document_storage_mode': instance.documentStorageMode,
  'max_copies_per_job': instance.maxCopiesPerJob,
};
