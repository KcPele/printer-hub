// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'scan_settings_output_color_mode.dart';
import 'scan_settings_output_format.dart';
import 'scan_settings_output_source.dart';

part 'scan_settings_output.g.dart';

/// FR-SCN-004 to FR-SCN-008.
@JsonSerializable()
class ScanSettingsOutput {
  const ScanSettingsOutput({
    required this.mediaSize,
    this.colorMode = ScanSettingsOutputColorMode.auto,
    this.duplex = false,
    this.format = ScanSettingsOutputFormat.undefined0,
    this.resolutionDpi = 300,
    this.searchablePdf = false,
    this.source = ScanSettingsOutputSource.auto,
  });

  factory ScanSettingsOutput.fromJson(Map<String, Object?> json) =>
      _$ScanSettingsOutputFromJson(json);

  @JsonKey(name: 'color_mode')
  final ScanSettingsOutputColorMode colorMode;
  final bool duplex;
  final ScanSettingsOutputFormat format;
  @JsonKey(name: 'media_size')
  final String? mediaSize;
  @JsonKey(name: 'resolution_dpi')
  final int resolutionDpi;
  @JsonKey(name: 'searchable_pdf')
  final bool searchablePdf;
  final ScanSettingsOutputSource source;

  Map<String, Object?> toJson() => _$ScanSettingsOutputToJson(this);
}
