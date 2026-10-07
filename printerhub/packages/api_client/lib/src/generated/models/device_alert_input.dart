// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_alert_input_severity.dart';

part 'device_alert_input.g.dart';

/// FR-MON-004.
@JsonSerializable()
class DeviceAlertInput {
  const DeviceAlertInput({
    required this.code,
    this.severity = DeviceAlertInputSeverity.warning,
    this.message,
  });

  factory DeviceAlertInput.fromJson(Map<String, Object?> json) =>
      _$DeviceAlertInputFromJson(json);

  /// For example media-jam, toner-low, door-open
  final String code;
  final String? message;
  final DeviceAlertInputSeverity severity;

  Map<String, Object?> toJson() => _$DeviceAlertInputToJson(this);
}
