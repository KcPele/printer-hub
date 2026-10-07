// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'protocols_output.g.dart';

@JsonSerializable()
class ProtocolsOutput {
  const ProtocolsOutput({
    required this.airprint,
    required this.escl,
    required this.httpEws,
    required this.ipp,
    required this.ipps,
    required this.mopria,
    required this.smbScan,
    required this.snmp,
  });

  factory ProtocolsOutput.fromJson(Map<String, Object?> json) =>
      _$ProtocolsOutputFromJson(json);

  final bool? airprint;
  final bool? escl;
  @JsonKey(name: 'http_ews')
  final bool? httpEws;
  final bool? ipp;
  final bool? ipps;
  final bool? mopria;
  @JsonKey(name: 'smb_scan')
  final bool? smbScan;
  final bool? snmp;

  Map<String, Object?> toJson() => _$ProtocolsOutputToJson(this);
}
