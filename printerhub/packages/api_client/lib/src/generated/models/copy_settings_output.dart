// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'copy_settings_output_color_mode.dart';
import 'copy_settings_output_method.dart';
import 'copy_settings_output_scaling.dart';
import 'duplex_mode.dart';

part 'copy_settings_output.g.dart';

/// FR-CPY-002.
@JsonSerializable()
class CopySettingsOutput {
  const CopySettingsOutput({
    required this.mediaSize,
    required this.scalePercent,
    required this.tray,
    this.collate = true,
    this.colorMode = CopySettingsOutputColorMode.auto,
    this.copies = 1,
    this.method = CopySettingsOutputMethod.scanThenPrint,
    this.outputDuplex = DuplexMode.oneSided,
    this.scaling = CopySettingsOutputScaling.actual,
    this.sourceDuplex = false,
  });

  factory CopySettingsOutput.fromJson(Map<String, Object?> json) =>
      _$CopySettingsOutputFromJson(json);

  final bool collate;
  @JsonKey(name: 'color_mode')
  final CopySettingsOutputColorMode colorMode;
  final int copies;
  @JsonKey(name: 'media_size')
  final String? mediaSize;
  final CopySettingsOutputMethod method;
  @JsonKey(name: 'output_duplex')
  final DuplexMode outputDuplex;
  @JsonKey(name: 'scale_percent')
  final int? scalePercent;
  final CopySettingsOutputScaling scaling;
  @JsonKey(name: 'source_duplex')
  final bool sourceDuplex;
  final String? tray;

  Map<String, Object?> toJson() => _$CopySettingsOutputToJson(this);
}
