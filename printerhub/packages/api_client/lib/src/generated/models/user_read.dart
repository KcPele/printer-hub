// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'user_preferences_output.dart';

part 'user_read.g.dart';

@JsonSerializable()
class UserRead {
  const UserRead({
    required this.createdAt,
    required this.email,
    required this.emailVerifiedAt,
    required this.id,
    required this.isSuperuser,
    required this.name,
    required this.preferences,
  });

  factory UserRead.fromJson(Map<String, Object?> json) =>
      _$UserReadFromJson(json);

  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final String email;

  /// Null until the email address is verified with the emailed code
  @JsonKey(name: 'email_verified_at')
  final DateTime? emailVerifiedAt;
  final String id;
  @JsonKey(name: 'is_superuser')
  final bool isSuperuser;
  final String name;
  final UserPreferencesOutput preferences;

  Map<String, Object?> toJson() => _$UserReadToJson(this);
}
