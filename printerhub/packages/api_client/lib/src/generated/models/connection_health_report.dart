// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'connection_health.dart';

part 'connection_health_report.g.dart';

/// What a client observed when it used or tested the connection.
@JsonSerializable()
class ConnectionHealthReport {
  const ConnectionHealthReport({
    required this.health,
    this.error,
    this.latencyMs,
  });

  factory ConnectionHealthReport.fromJson(Map<String, Object?> json) =>
      _$ConnectionHealthReportFromJson(json);

  final String? error;
  final ConnectionHealth health;
  @JsonKey(name: 'latency_ms')
  final int? latencyMs;

  Map<String, Object?> toJson() => _$ConnectionHealthReportToJson(this);
}
