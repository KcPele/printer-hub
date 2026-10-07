// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'password_reset_request.g.dart';

@JsonSerializable()
class PasswordResetRequest {
  const PasswordResetRequest({
    required this.code,
    required this.email,
    required this.newPassword,
  });

  factory PasswordResetRequest.fromJson(Map<String, Object?> json) =>
      _$PasswordResetRequestFromJson(json);

  final String code;
  final String email;
  @JsonKey(name: 'new_password')
  final String newPassword;

  Map<String, Object?> toJson() => _$PasswordResetRequestToJson(this);
}
