// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_alert_output_severity.dart';

part 'device_alert_output.g.dart';

/// FR-MON-004.
@JsonSerializable()
class DeviceAlertOutput {
  const DeviceAlertOutput({
    required this.code,
    required this.message,
    this.severity = DeviceAlertOutputSeverity.warning,
  });

  factory DeviceAlertOutput.fromJson(Map<String, Object?> json) =>
      _$DeviceAlertOutputFromJson(json);

  /// For example media-jam, toner-low, door-open
  final String code;
  final String? message;
  final DeviceAlertOutputSeverity severity;

  Map<String, Object?> toJson() => _$DeviceAlertOutputToJson(this);
}
