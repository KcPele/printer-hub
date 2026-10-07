// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'organization_settings_input.dart';

part 'organization_update.g.dart';

@JsonSerializable()
class OrganizationUpdate {
  const OrganizationUpdate({this.name, this.settings});

  factory OrganizationUpdate.fromJson(Map<String, Object?> json) =>
      _$OrganizationUpdateFromJson(json);

  final String? name;
  final OrganizationSettingsInput? settings;

  Map<String, Object?> toJson() => _$OrganizationUpdateToJson(this);
}
