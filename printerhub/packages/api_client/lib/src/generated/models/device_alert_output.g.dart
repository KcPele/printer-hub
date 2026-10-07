// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_alert_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceAlertOutput _$DeviceAlertOutputFromJson(Map<String, dynamic> json) =>
    DeviceAlertOutput(
      code: json['code'] as String,
      message: json['message'] as String?,
      severity: json['severity'] == null
          ? DeviceAlertOutputSeverity.warning
          : DeviceAlertOutputSeverity.fromJson(json['severity'] as String),
    );

Map<String, dynamic> _$DeviceAlertOutputToJson(DeviceAlertOutput instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': ?instance.message,
      'severity': instance.severity.toJson(),
    };
