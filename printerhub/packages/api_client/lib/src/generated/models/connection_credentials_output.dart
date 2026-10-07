// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'connection_credentials_output.g.dart';

/// Secrets for a connection. Encrypted at rest; returned only by the credentials endpoint.
@JsonSerializable()
class ConnectionCredentialsOutput {
  const ConnectionCredentialsOutput({
    required this.extra,
    required this.password,
    required this.username,
  });

  factory ConnectionCredentialsOutput.fromJson(Map<String, Object?> json) =>
      _$ConnectionCredentialsOutputFromJson(json);

  final Map<String, String> extra;
  final String? password;
  final String? username;

  Map<String, Object?> toJson() => _$ConnectionCredentialsOutputToJson(this);
}
