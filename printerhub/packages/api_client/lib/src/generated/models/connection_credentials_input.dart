// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'connection_credentials_input.g.dart';

/// Secrets for a connection. Encrypted at rest; returned only by the credentials endpoint.
@JsonSerializable()
class ConnectionCredentialsInput {
  const ConnectionCredentialsInput({this.extra, this.password, this.username});

  factory ConnectionCredentialsInput.fromJson(Map<String, Object?> json) =>
      _$ConnectionCredentialsInputFromJson(json);

  final Map<String, String>? extra;
  final String? password;
  final String? username;

  Map<String, Object?> toJson() => _$ConnectionCredentialsInputToJson(this);
}
