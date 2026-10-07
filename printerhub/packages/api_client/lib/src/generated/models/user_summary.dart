// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'user_summary.g.dart';

/// The public face of a user inside an organization.
@JsonSerializable()
class UserSummary {
  const UserSummary({
    required this.email,
    required this.id,
    required this.name,
  });

  factory UserSummary.fromJson(Map<String, Object?> json) =>
      _$UserSummaryFromJson(json);

  final String email;
  final String id;
  final String name;

  Map<String, Object?> toJson() => _$UserSummaryToJson(this);
}
