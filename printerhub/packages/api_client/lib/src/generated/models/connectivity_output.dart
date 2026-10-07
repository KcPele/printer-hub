// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'connectivity_output.g.dart';

@JsonSerializable()
class ConnectivityOutput {
  const ConnectivityOutput({
    required this.bleBeacon,
    required this.ethernet,
    required this.nfc,
    required this.usb,
    required this.wifi,
    required this.wifiDirect,
  });

  factory ConnectivityOutput.fromJson(Map<String, Object?> json) =>
      _$ConnectivityOutputFromJson(json);

  @JsonKey(name: 'ble_beacon')
  final bool? bleBeacon;
  final bool? ethernet;
  final bool? nfc;
  final bool? usb;
  final bool? wifi;
  @JsonKey(name: 'wifi_direct')
  final bool? wifiDirect;

  Map<String, Object?> toJson() => _$ConnectivityOutputToJson(this);
}
