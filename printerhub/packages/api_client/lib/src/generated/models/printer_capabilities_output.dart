// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'connectivity_output.dart';
import 'copy_capabilities_output.dart';
import 'print_capabilities_output.dart';
import 'protocols_output.dart';
import 'scan_capabilities_output.dart';
import 'status_capabilities_output.dart';

part 'printer_capabilities_output.g.dart';

@JsonSerializable()
class PrinterCapabilitiesOutput {
  const PrinterCapabilitiesOutput({
    required this.connectivity,
    required this.copy,
    required this.print,
    required this.protocols,
    required this.scan,
    required this.status,
    this.schemaVersion = 1,
  });

  factory PrinterCapabilitiesOutput.fromJson(Map<String, Object?> json) =>
      _$PrinterCapabilitiesOutputFromJson(json);

  final ConnectivityOutput connectivity;
  final CopyCapabilitiesOutput copy;
  final PrintCapabilitiesOutput print;
  final ProtocolsOutput protocols;
  final ScanCapabilitiesOutput scan;
  @JsonKey(name: 'schema_version')
  final int schemaVersion;
  final StatusCapabilitiesOutput status;

  Map<String, Object?> toJson() => _$PrinterCapabilitiesOutputToJson(this);
}
