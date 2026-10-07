// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'duplex_mode.dart';
import 'media_tray_output.dart';

part 'print_capabilities_output.g.dart';

@JsonSerializable()
class PrintCapabilitiesOutput {
  const PrintCapabilitiesOutput({
    required this.documentFormats,
    required this.duplexModes,
    required this.finishing,
    required this.maxCopies,
    required this.mediaSizes,
    required this.mediaTypes,
    required this.qualityModes,
    required this.resolutionsDpi,
    required this.trays,
    this.collation = false,
    this.color = false,
    this.securePrint = false,
    this.supported = false,
  });

  factory PrintCapabilitiesOutput.fromJson(Map<String, Object?> json) =>
      _$PrintCapabilitiesOutputFromJson(json);

  final bool collation;
  final bool color;
  @JsonKey(name: 'document_formats')
  final List<String> documentFormats;
  @JsonKey(name: 'duplex_modes')
  final List<DuplexMode> duplexModes;
  final List<String> finishing;
  @JsonKey(name: 'max_copies')
  final int? maxCopies;
  @JsonKey(name: 'media_sizes')
  final List<String> mediaSizes;
  @JsonKey(name: 'media_types')
  final List<String> mediaTypes;
  @JsonKey(name: 'quality_modes')
  final List<String> qualityModes;
  @JsonKey(name: 'resolutions_dpi')
  final List<int> resolutionsDpi;
  @JsonKey(name: 'secure_print')
  final bool securePrint;
  final bool supported;
  final List<MediaTrayOutput> trays;

  Map<String, Object?> toJson() => _$PrintCapabilitiesOutputToJson(this);
}
