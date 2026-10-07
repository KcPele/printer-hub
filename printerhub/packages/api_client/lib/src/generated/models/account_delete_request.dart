// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'account_delete_request.g.dart';

@JsonSerializable()
class AccountDeleteRequest {
  const AccountDeleteRequest({required this.password});

  factory AccountDeleteRequest.fromJson(Map<String, Object?> json) =>
      _$AccountDeleteRequestFromJson(json);

  /// The current password
  final String password;

  Map<String, Object?> toJson() => _$AccountDeleteRequestToJson(this);
}
