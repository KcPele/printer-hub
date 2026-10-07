// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'connection_configuration_input.dart';
import 'connection_credentials_input.dart';
import 'connection_purpose.dart';

part 'connection_update.g.dart';

/// Fields left out are unchanged. Send `credentials: null` to remove stored credentials.
@JsonSerializable()
class ConnectionUpdate {
  const ConnectionUpdate({this.configuration, this.credentials, this.purposes});

  factory ConnectionUpdate.fromJson(Map<String, Object?> json) =>
      _$ConnectionUpdateFromJson(json);

  final ConnectionConfigurationInput? configuration;
  final ConnectionCredentialsInput? credentials;
  final List<ConnectionPurpose>? purposes;

  Map<String, Object?> toJson() => _$ConnectionUpdateToJson(this);
}
