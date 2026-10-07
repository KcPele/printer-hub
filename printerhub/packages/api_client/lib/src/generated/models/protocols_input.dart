// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'protocols_input.g.dart';

@JsonSerializable()
class ProtocolsInput {
  const ProtocolsInput({
    this.airprint,
    this.escl,
    this.httpEws,
    this.ipp,
    this.ipps,
    this.mopria,
    this.smbScan,
    this.snmp,
  });

  factory ProtocolsInput.fromJson(Map<String, Object?> json) =>
      _$ProtocolsInputFromJson(json);

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

  Map<String, Object?> toJson() => _$ProtocolsInputToJson(this);
}
