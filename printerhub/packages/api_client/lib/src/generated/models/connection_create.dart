// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'connection_configuration_input.dart';
import 'connection_credentials_input.dart';
import 'connection_purpose.dart';
import 'connection_type.dart';

part 'connection_create.g.dart';

@JsonSerializable()
class ConnectionCreate {
  const ConnectionCreate({
    required this.purposes,
    required this.type,
    this.configuration,
    this.credentials,
    this.priority,
  });

  factory ConnectionCreate.fromJson(Map<String, Object?> json) =>
      _$ConnectionCreateFromJson(json);

  final ConnectionConfigurationInput? configuration;
  final ConnectionCredentialsInput? credentials;
  final int? priority;
  final List<ConnectionPurpose> purposes;
  final ConnectionType type;

  Map<String, Object?> toJson() => _$ConnectionCreateToJson(this);
}
