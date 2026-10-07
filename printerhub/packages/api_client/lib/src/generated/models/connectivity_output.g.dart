// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectivityOutput _$ConnectivityOutputFromJson(Map<String, dynamic> json) =>
    ConnectivityOutput(
      bleBeacon: json['ble_beacon'] as bool?,
      ethernet: json['ethernet'] as bool?,
      nfc: json['nfc'] as bool?,
      usb: json['usb'] as bool?,
      wifi: json['wifi'] as bool?,
      wifiDirect: json['wifi_direct'] as bool?,
    );

Map<String, dynamic> _$ConnectivityOutputToJson(ConnectivityOutput instance) =>
    <String, dynamic>{
      'ble_beacon': ?instance.bleBeacon,
      'ethernet': ?instance.ethernet,
      'nfc': ?instance.nfc,
      'usb': ?instance.usb,
      'wifi': ?instance.wifi,
      'wifi_direct': ?instance.wifiDirect,
    };
