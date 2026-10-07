// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'organization_create.g.dart';

@JsonSerializable()
class OrganizationCreate {
  const OrganizationCreate({required this.name});

  factory OrganizationCreate.fromJson(Map<String, Object?> json) =>
      _$OrganizationCreateFromJson(json);

  final String name;

  Map<String, Object?> toJson() => _$OrganizationCreateToJson(this);
}
