// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'organization_settings_output_document_storage_mode.dart';
import 'role.dart';

part 'organization_settings_output.g.dart';

/// Organization policy. Job and document creation enforce these (FRD §19, §41).
@JsonSerializable()
class OrganizationSettingsOutput {
  const OrganizationSettingsOutput({
    required this.colorPrintingRoles,
    required this.documentRetentionDays,
    required this.maxCopiesPerJob,
    this.documentStorageMode =
        OrganizationSettingsOutputDocumentStorageMode.cloudAllowed,
  });

  factory OrganizationSettingsOutput.fromJson(Map<String, Object?> json) =>
      _$OrganizationSettingsOutputFromJson(json);

  @JsonKey(name: 'color_printing_roles')
  final List<Role> colorPrintingRoles;
  @JsonKey(name: 'document_retention_days')
  final int? documentRetentionDays;
  @JsonKey(name: 'document_storage_mode')
  final OrganizationSettingsOutputDocumentStorageMode documentStorageMode;
  @JsonKey(name: 'max_copies_per_job')
  final int? maxCopiesPerJob;

  Map<String, Object?> toJson() => _$OrganizationSettingsOutputToJson(this);
}
