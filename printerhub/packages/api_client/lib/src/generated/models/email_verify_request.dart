// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'email_verify_request.g.dart';

@JsonSerializable()
class EmailVerifyRequest {
  const EmailVerifyRequest({required this.code});

  factory EmailVerifyRequest.fromJson(Map<String, Object?> json) =>
      _$EmailVerifyRequestFromJson(json);

  final String code;

  Map<String, Object?> toJson() => _$EmailVerifyRequestToJson(this);
}
