// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_settings_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganizationSettingsOutput _$OrganizationSettingsOutputFromJson(
  Map<String, dynamic> json,
) => OrganizationSettingsOutput(
  colorPrintingRoles: (json['color_printing_roles'] as List<dynamic>)
      .map((e) => Role.fromJson(e as String))
      .toList(),
  documentRetentionDays: (json['document_retention_days'] as num?)?.toInt(),
  maxCopiesPerJob: (json['max_copies_per_job'] as num?)?.toInt(),
  documentStorageMode: json['document_storage_mode'] == null
      ? OrganizationSettingsOutputDocumentStorageMode.cloudAllowed
      : OrganizationSettingsOutputDocumentStorageMode.fromJson(
          json['document_storage_mode'] as String,
        ),
);

Map<String, dynamic> _$OrganizationSettingsOutputToJson(
  OrganizationSettingsOutput instance,
) => <String, dynamic>{
  'color_printing_roles': instance.colorPrintingRoles,
  'document_retention_days': instance.documentRetentionDays,
  'document_storage_mode': instance.documentStorageMode,
  'max_copies_per_job': instance.maxCopiesPerJob,
};
