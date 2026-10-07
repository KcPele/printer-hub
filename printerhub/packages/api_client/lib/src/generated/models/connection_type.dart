// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum ConnectionType {
  @JsonValue('ipp')
  ipp('ipp'),
  @JsonValue('ipps')
  ipps('ipps'),
  @JsonValue('airprint')
  airprint('airprint'),
  @JsonValue('android_print')
  androidPrint('android_print'),
  @JsonValue('mopria')
  mopria('mopria'),
  @JsonValue('escl')
  escl('escl'),
  @JsonValue('wifi_direct')
  wifiDirect('wifi_direct'),
  @JsonValue('usb')
  usb('usb'),
  @JsonValue('http')
  http('http'),
  @JsonValue('snmp')
  snmp('snmp'),
  @JsonValue('smb')
  smb('smb'),
  @JsonValue('sftp')
  sftp('sftp'),
  @JsonValue('gateway')
  gateway('gateway'),
  @JsonValue('cloud_relay')
  cloudRelay('cloud_relay'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ConnectionType(this.json);

  factory ConnectionType.fromJson(String json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final String? json;
  String toJson() {
    final value = json;
    if (value == null) {
      throw StateError(
        'Cannot convert enum value with null JSON representation to String. '
        'This usually happens for \$unknown or @JsonValue(null) entries.',
      );
    }
    return value as String;
  }

  @override
  String toString() => json?.toString() ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<ConnectionType> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
