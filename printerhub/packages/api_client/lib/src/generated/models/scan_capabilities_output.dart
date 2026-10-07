// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'scan_color_mode.dart';
import 'scan_source.dart';

part 'scan_capabilities_output.g.dart';

@JsonSerializable()
class ScanCapabilitiesOutput {
  const ScanCapabilitiesOutput({
    required this.colorModes,
    required this.documentFormats,
    required this.maxHeightMm,
    required this.maxWidthMm,
    required this.resolutionsDpi,
    required this.sources,
    this.adfDuplex = false,
    this.supported = false,
  });

  factory ScanCapabilitiesOutput.fromJson(Map<String, Object?> json) =>
      _$ScanCapabilitiesOutputFromJson(json);

  @JsonKey(name: 'adf_duplex')
  final bool adfDuplex;
  @JsonKey(name: 'color_modes')
  final List<ScanColorMode> colorModes;
  @JsonKey(name: 'document_formats')
  final List<String> documentFormats;
  @JsonKey(name: 'max_height_mm')
  final num? maxHeightMm;
  @JsonKey(name: 'max_width_mm')
  final num? maxWidthMm;
  @JsonKey(name: 'resolutions_dpi')
  final List<int> resolutionsDpi;
  final List<ScanSource> sources;
  final bool supported;

  Map<String, Object?> toJson() => _$ScanCapabilitiesOutputToJson(this);
}
