// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'printer_capabilities_output.dart';

part 'capability_profile_read.g.dart';

@JsonSerializable()
class CapabilityProfileRead {
  const CapabilityProfileRead({
    required this.capabilities,
    required this.displayName,
    required this.id,
    required this.manufacturer,
    required this.modelPatterns,
    required this.notes,
    required this.optionalFeatures,
    required this.updatedAt,
    required this.version,
  });

  factory CapabilityProfileRead.fromJson(Map<String, Object?> json) =>
      _$CapabilityProfileReadFromJson(json);

  final PrinterCapabilitiesOutput capabilities;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String id;
  final String manufacturer;
  @JsonKey(name: 'model_patterns')
  final List<String> modelPatterns;
  final List<String> notes;
  @JsonKey(name: 'optional_features')
  final List<String> optionalFeatures;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  final int version;

  Map<String, Object?> toJson() => _$CapabilityProfileReadToJson(this);
}
