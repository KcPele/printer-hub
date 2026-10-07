// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'scan_settings_input_color_mode.dart';
import 'scan_settings_input_format.dart';
import 'scan_settings_input_source.dart';

part 'scan_settings_input.g.dart';

/// FR-SCN-004 to FR-SCN-008.
@JsonSerializable()
class ScanSettingsInput {
  const ScanSettingsInput({
    this.mediaSize,
    this.colorMode = ScanSettingsInputColorMode.auto,
    this.duplex = false,
    this.format = ScanSettingsInputFormat.undefined0,
    this.resolutionDpi = 300,
    this.searchablePdf = false,
    this.source = ScanSettingsInputSource.auto,
  });

  factory ScanSettingsInput.fromJson(Map<String, Object?> json) =>
      _$ScanSettingsInputFromJson(json);

  @JsonKey(name: 'color_mode')
  final ScanSettingsInputColorMode colorMode;
  final bool duplex;
  final ScanSettingsInputFormat format;
  @JsonKey(name: 'media_size')
  final String? mediaSize;
  @JsonKey(name: 'resolution_dpi')
  final int resolutionDpi;
  @JsonKey(name: 'searchable_pdf')
  final bool searchablePdf;
  final ScanSettingsInputSource source;

  Map<String, Object?> toJson() => _$ScanSettingsInputToJson(this);
}
