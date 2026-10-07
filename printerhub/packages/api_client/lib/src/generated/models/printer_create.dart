// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'connection_create.dart';
import 'printer_capabilities_input.dart';

part 'printer_create.g.dart';

@JsonSerializable()
class PrinterCreate {
  const PrinterCreate({
    required this.friendlyName,
    this.capabilities,
    this.connections,
    this.location,
    this.manufacturer,
    this.model,
    this.serialNumber,
  });

  factory PrinterCreate.fromJson(Map<String, Object?> json) =>
      _$PrinterCreateFromJson(json);

  final PrinterCapabilitiesInput? capabilities;
  final List<ConnectionCreate>? connections;
  @JsonKey(name: 'friendly_name')
  final String friendlyName;
  final String? location;
  final String? manufacturer;
  final String? model;
  @JsonKey(name: 'serial_number')
  final String? serialNumber;

  Map<String, Object?> toJson() => _$PrinterCreateToJson(this);
}
