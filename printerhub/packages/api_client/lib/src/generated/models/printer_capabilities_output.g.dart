// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_capabilities_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrinterCapabilitiesOutput _$PrinterCapabilitiesOutputFromJson(
  Map<String, dynamic> json,
) => PrinterCapabilitiesOutput(
  connectivity: ConnectivityOutput.fromJson(
    json['connectivity'] as Map<String, dynamic>,
  ),
  copy: CopyCapabilitiesOutput.fromJson(json['copy'] as Map<String, dynamic>),
  print: PrintCapabilitiesOutput.fromJson(
    json['print'] as Map<String, dynamic>,
  ),
  protocols: ProtocolsOutput.fromJson(
    json['protocols'] as Map<String, dynamic>,
  ),
  scan: ScanCapabilitiesOutput.fromJson(json['scan'] as Map<String, dynamic>),
  status: StatusCapabilitiesOutput.fromJson(
    json['status'] as Map<String, dynamic>,
  ),
  schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$PrinterCapabilitiesOutputToJson(
  PrinterCapabilitiesOutput instance,
) => <String, dynamic>{
  'connectivity': instance.connectivity.toJson(),
  'copy': instance.copy.toJson(),
  'print': instance.print.toJson(),
  'protocols': instance.protocols.toJson(),
  'scan': instance.scan.toJson(),
  'schema_version': instance.schemaVersion,
  'status': instance.status.toJson(),
};
