// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'protocols_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProtocolsInput _$ProtocolsInputFromJson(Map<String, dynamic> json) =>
    ProtocolsInput(
      airprint: json['airprint'] as bool?,
      escl: json['escl'] as bool?,
      httpEws: json['http_ews'] as bool?,
      ipp: json['ipp'] as bool?,
      ipps: json['ipps'] as bool?,
      mopria: json['mopria'] as bool?,
      smbScan: json['smb_scan'] as bool?,
      snmp: json['snmp'] as bool?,
    );

Map<String, dynamic> _$ProtocolsInputToJson(ProtocolsInput instance) =>
    <String, dynamic>{
      'airprint': instance.airprint,
      'escl': instance.escl,
      'http_ews': instance.httpEws,
      'ipp': instance.ipp,
      'ipps': instance.ipps,
      'mopria': instance.mopria,
      'smb_scan': instance.smbScan,
      'snmp': instance.snmp,
    };
