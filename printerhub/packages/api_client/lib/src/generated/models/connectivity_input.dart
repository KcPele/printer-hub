// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'connectivity_input.g.dart';

@JsonSerializable()
class ConnectivityInput {
  const ConnectivityInput({
    this.bleBeacon,
    this.ethernet,
    this.nfc,
    this.usb,
    this.wifi,
    this.wifiDirect,
  });

  factory ConnectivityInput.fromJson(Map<String, Object?> json) =>
      _$ConnectivityInputFromJson(json);

  @JsonKey(name: 'ble_beacon')
  final bool? bleBeacon;
  final bool? ethernet;
  final bool? nfc;
  final bool? usb;
  final bool? wifi;
  @JsonKey(name: 'wifi_direct')
  final bool? wifiDirect;

  Map<String, Object?> toJson() => _$ConnectivityInputToJson(this);
}
