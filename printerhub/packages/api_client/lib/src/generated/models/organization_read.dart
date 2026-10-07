// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'organization_settings_output.dart';
import 'role.dart';

part 'organization_read.g.dart';

@JsonSerializable()
class OrganizationRead {
  const OrganizationRead({
    required this.createdAt,
    required this.id,
    required this.name,
    required this.role,
    required this.settings,
    required this.slug,
  });

  factory OrganizationRead.fromJson(Map<String, Object?> json) =>
      _$OrganizationReadFromJson(json);

  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final String id;
  final String name;

  /// The caller's role in this organization
  final Role role;
  final OrganizationSettingsOutput settings;
  final String slug;

  Map<String, Object?> toJson() => _$OrganizationReadToJson(this);
}
