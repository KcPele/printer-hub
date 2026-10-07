// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'printer_update.g.dart';

/// Fields left out are unchanged.
@JsonSerializable()
class PrinterUpdate {
  const PrinterUpdate({
    this.autoFallbackEnabled,
    this.friendlyName,
    this.location,
    this.manufacturer,
    this.model,
    this.serialNumber,
  });

  factory PrinterUpdate.fromJson(Map<String, Object?> json) =>
      _$PrinterUpdateFromJson(json);

  @JsonKey(name: 'auto_fallback_enabled')
  final bool? autoFallbackEnabled;
  @JsonKey(name: 'friendly_name')
  final String? friendlyName;
  final String? location;
  final String? manufacturer;
  final String? model;
  @JsonKey(name: 'serial_number')
  final String? serialNumber;

  Map<String, Object?> toJson() => _$PrinterUpdateToJson(this);
}
