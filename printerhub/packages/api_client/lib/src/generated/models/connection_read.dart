// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'connection_configuration_output.dart';
import 'connection_health.dart';
import 'connection_purpose.dart';
import 'connection_type.dart';

part 'connection_read.g.dart';

@JsonSerializable()
class ConnectionRead {
  const ConnectionRead({
    required this.configuration,
    required this.createdAt,
    required this.hasCredentials,
    required this.health,
    required this.id,
    required this.lastError,
    required this.lastFailureAt,
    required this.lastLatencyMs,
    required this.lastSuccessAt,
    required this.printerId,
    required this.priority,
    required this.purposes,
    required this.type,
    required this.updatedAt,
  });

  factory ConnectionRead.fromJson(Map<String, Object?> json) =>
      _$ConnectionReadFromJson(json);

  final ConnectionConfigurationOutput configuration;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'has_credentials')
  final bool hasCredentials;
  final ConnectionHealth health;
  final String id;
  @JsonKey(name: 'last_error')
  final String? lastError;
  @JsonKey(name: 'last_failure_at')
  final DateTime? lastFailureAt;
  @JsonKey(name: 'last_latency_ms')
  final int? lastLatencyMs;
  @JsonKey(name: 'last_success_at')
  final DateTime? lastSuccessAt;
  @JsonKey(name: 'printer_id')
  final String printerId;
  final int priority;
  final List<ConnectionPurpose> purposes;
  final ConnectionType type;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, Object?> toJson() => _$ConnectionReadToJson(this);
}
