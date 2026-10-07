// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'organization_settings_input_document_storage_mode.dart';
import 'role.dart';

part 'organization_settings_input.g.dart';

/// Organization policy. Job and document creation enforce these (FRD §19, §41).
@JsonSerializable()
class OrganizationSettingsInput {
  const OrganizationSettingsInput({
    this.documentStorageMode =
        OrganizationSettingsInputDocumentStorageMode.cloudAllowed,
    this.colorPrintingRoles,
    this.documentRetentionDays,
    this.maxCopiesPerJob,
  });

  factory OrganizationSettingsInput.fromJson(Map<String, Object?> json) =>
      _$OrganizationSettingsInputFromJson(json);

  @JsonKey(name: 'color_printing_roles')
  final List<Role>? colorPrintingRoles;
  @JsonKey(name: 'document_retention_days')
  final int? documentRetentionDays;
  @JsonKey(name: 'document_storage_mode')
  final OrganizationSettingsInputDocumentStorageMode documentStorageMode;
  @JsonKey(name: 'max_copies_per_job')
  final int? maxCopiesPerJob;

  Map<String, Object?> toJson() => _$OrganizationSettingsInputToJson(this);
}
