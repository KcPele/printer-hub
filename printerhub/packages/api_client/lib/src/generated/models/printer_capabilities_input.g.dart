// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_capabilities_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrinterCapabilitiesInput _$PrinterCapabilitiesInputFromJson(
  Map<String, dynamic> json,
) => PrinterCapabilitiesInput(
  schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
  connectivity: json['connectivity'] == null
      ? null
      : ConnectivityInput.fromJson(
          json['connectivity'] as Map<String, dynamic>,
        ),
  copy: json['copy'] == null
      ? null
      : CopyCapabilitiesInput.fromJson(json['copy'] as Map<String, dynamic>),
  print: json['print'] == null
      ? null
      : PrintCapabilitiesInput.fromJson(json['print'] as Map<String, dynamic>),
  protocols: json['protocols'] == null
      ? null
      : ProtocolsInput.fromJson(json['protocols'] as Map<String, dynamic>),
  scan: json['scan'] == null
      ? null
      : ScanCapabilitiesInput.fromJson(json['scan'] as Map<String, dynamic>),
  status: json['status'] == null
      ? null
      : StatusCapabilitiesInput.fromJson(
          json['status'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$PrinterCapabilitiesInputToJson(
  PrinterCapabilitiesInput instance,
) => <String, dynamic>{
  'connectivity': ?instance.connectivity?.toJson(),
  'copy': ?instance.copy?.toJson(),
  'print': ?instance.print?.toJson(),
  'protocols': ?instance.protocols?.toJson(),
  'scan': ?instance.scan?.toJson(),
  'schema_version': instance.schemaVersion,
  'status': ?instance.status?.toJson(),
};
