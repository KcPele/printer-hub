// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'duplex_mode.dart';
import 'media_tray_input.dart';

part 'print_capabilities_input.g.dart';

@JsonSerializable()
class PrintCapabilitiesInput {
  const PrintCapabilitiesInput({
    this.documentFormats,
    this.duplexModes,
    this.finishing,
    this.maxCopies,
    this.mediaSizes,
    this.mediaTypes,
    this.qualityModes,
    this.resolutionsDpi,
    this.trays,
    this.collation = false,
    this.color = false,
    this.securePrint = false,
    this.supported = false,
  });

  factory PrintCapabilitiesInput.fromJson(Map<String, Object?> json) =>
      _$PrintCapabilitiesInputFromJson(json);

  final bool collation;
  final bool color;
  @JsonKey(name: 'document_formats')
  final List<String>? documentFormats;
  @JsonKey(name: 'duplex_modes')
  final List<DuplexMode>? duplexModes;
  final List<String>? finishing;
  @JsonKey(name: 'max_copies')
  final int? maxCopies;
  @JsonKey(name: 'media_sizes')
  final List<String>? mediaSizes;
  @JsonKey(name: 'media_types')
  final List<String>? mediaTypes;
  @JsonKey(name: 'quality_modes')
  final List<String>? qualityModes;
  @JsonKey(name: 'resolutions_dpi')
  final List<int>? resolutionsDpi;
  @JsonKey(name: 'secure_print')
  final bool securePrint;
  final bool supported;
  final List<MediaTrayInput>? trays;

  Map<String, Object?> toJson() => _$PrintCapabilitiesInputToJson(this);
}
