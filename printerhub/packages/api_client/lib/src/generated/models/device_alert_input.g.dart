// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_alert_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceAlertInput _$DeviceAlertInputFromJson(Map<String, dynamic> json) =>
    DeviceAlertInput(
      code: json['code'] as String,
      severity: json['severity'] == null
          ? DeviceAlertInputSeverity.warning
          : DeviceAlertInputSeverity.fromJson(json['severity'] as String),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$DeviceAlertInputToJson(DeviceAlertInput instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': ?instance.message,
      'severity': instance.severity.toJson(),
    };
