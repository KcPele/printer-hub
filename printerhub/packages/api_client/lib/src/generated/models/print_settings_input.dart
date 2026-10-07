// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'duplex_mode.dart';
import 'print_settings_input_color_mode.dart';
import 'print_settings_input_orientation.dart';
import 'print_settings_input_scaling.dart';

part 'print_settings_input.g.dart';

/// FR-PRN-005 to FR-PRN-016, FR-PRN-024.
@JsonSerializable()
class PrintSettingsInput {
  const PrintSettingsInput({
    this.finishing,
    this.mediaSize,
    this.mediaType,
    this.pageRanges,
    this.quality,
    this.scalePercent,
    this.tray,
    this.collate = true,
    this.colorMode = PrintSettingsInputColorMode.auto,
    this.copies = 1,
    this.duplex = DuplexMode.oneSided,
    this.orientation = PrintSettingsInputOrientation.auto,
    this.scaling = PrintSettingsInputScaling.fit,
    this.securePrint = false,
  });

  factory PrintSettingsInput.fromJson(Map<String, Object?> json) =>
      _$PrintSettingsInputFromJson(json);

  final bool collate;
  @JsonKey(name: 'color_mode')
  final PrintSettingsInputColorMode colorMode;
  final int copies;
  final DuplexMode duplex;
  final List<String>? finishing;
  @JsonKey(name: 'media_size')
  final String? mediaSize;
  @JsonKey(name: 'media_type')
  final String? mediaType;
  final PrintSettingsInputOrientation orientation;
  @JsonKey(name: 'page_ranges')
  final String? pageRanges;
  final String? quality;
  @JsonKey(name: 'scale_percent')
  final int? scalePercent;
  final PrintSettingsInputScaling scaling;
  @JsonKey(name: 'secure_print')
  final bool securePrint;
  final String? tray;

  Map<String, Object?> toJson() => _$PrintSettingsInputToJson(this);
}
