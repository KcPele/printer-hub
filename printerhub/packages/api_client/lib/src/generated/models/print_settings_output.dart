// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'duplex_mode.dart';
import 'print_settings_output_color_mode.dart';
import 'print_settings_output_orientation.dart';
import 'print_settings_output_scaling.dart';

part 'print_settings_output.g.dart';

/// FR-PRN-005 to FR-PRN-016, FR-PRN-024.
@JsonSerializable()
class PrintSettingsOutput {
  const PrintSettingsOutput({
    required this.finishing,
    required this.mediaSize,
    required this.mediaType,
    required this.pageRanges,
    required this.quality,
    required this.scalePercent,
    required this.tray,
    this.collate = true,
    this.colorMode = PrintSettingsOutputColorMode.auto,
    this.copies = 1,
    this.duplex = DuplexMode.oneSided,
    this.orientation = PrintSettingsOutputOrientation.auto,
    this.scaling = PrintSettingsOutputScaling.fit,
    this.securePrint = false,
  });

  factory PrintSettingsOutput.fromJson(Map<String, Object?> json) =>
      _$PrintSettingsOutputFromJson(json);

  final bool collate;
  @JsonKey(name: 'color_mode')
  final PrintSettingsOutputColorMode colorMode;
  final int copies;
  final DuplexMode duplex;
  final List<String> finishing;
  @JsonKey(name: 'media_size')
  final String? mediaSize;
  @JsonKey(name: 'media_type')
  final String? mediaType;
  final PrintSettingsOutputOrientation orientation;
  @JsonKey(name: 'page_ranges')
  final String? pageRanges;
  final String? quality;
  @JsonKey(name: 'scale_percent')
  final int? scalePercent;
  final PrintSettingsOutputScaling scaling;
  @JsonKey(name: 'secure_print')
  final bool securePrint;
  final String? tray;

  Map<String, Object?> toJson() => _$PrintSettingsOutputToJson(this);
}
