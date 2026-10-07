// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'connectivity_input.dart';
import 'copy_capabilities_input.dart';
import 'print_capabilities_input.dart';
import 'protocols_input.dart';
import 'scan_capabilities_input.dart';
import 'status_capabilities_input.dart';

part 'printer_capabilities_input.g.dart';

@JsonSerializable()
class PrinterCapabilitiesInput {
  const PrinterCapabilitiesInput({
    this.schemaVersion = 1,
    this.connectivity,
    this.copy,
    this.print,
    this.protocols,
    this.scan,
    this.status,
  });

  factory PrinterCapabilitiesInput.fromJson(Map<String, Object?> json) =>
      _$PrinterCapabilitiesInputFromJson(json);

  final ConnectivityInput? connectivity;
  final CopyCapabilitiesInput? copy;
  final PrintCapabilitiesInput? print;
  final ProtocolsInput? protocols;
  final ScanCapabilitiesInput? scan;
  @JsonKey(name: 'schema_version')
  final int schemaVersion;
  final StatusCapabilitiesInput? status;

  Map<String, Object?> toJson() => _$PrinterCapabilitiesInputToJson(this);
}
