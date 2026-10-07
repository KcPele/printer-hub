// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'scan_color_mode.dart';
import 'scan_source.dart';

part 'scan_capabilities_input.g.dart';

@JsonSerializable()
class ScanCapabilitiesInput {
  const ScanCapabilitiesInput({
    this.colorModes,
    this.documentFormats,
    this.maxHeightMm,
    this.maxWidthMm,
    this.resolutionsDpi,
    this.sources,
    this.adfDuplex = false,
    this.supported = false,
  });

  factory ScanCapabilitiesInput.fromJson(Map<String, Object?> json) =>
      _$ScanCapabilitiesInputFromJson(json);

  @JsonKey(name: 'adf_duplex')
  final bool adfDuplex;
  @JsonKey(name: 'color_modes')
  final List<ScanColorMode>? colorModes;
  @JsonKey(name: 'document_formats')
  final List<String>? documentFormats;
  @JsonKey(name: 'max_height_mm')
  final num? maxHeightMm;
  @JsonKey(name: 'max_width_mm')
  final num? maxWidthMm;
  @JsonKey(name: 'resolutions_dpi')
  final List<int>? resolutionsDpi;
  final List<ScanSource>? sources;
  final bool supported;

  Map<String, Object?> toJson() => _$ScanCapabilitiesInputToJson(this);
}
