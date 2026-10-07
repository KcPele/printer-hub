// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'copy_settings_input_color_mode.dart';
import 'copy_settings_input_method.dart';
import 'copy_settings_input_scaling.dart';
import 'duplex_mode.dart';

part 'copy_settings_input.g.dart';

/// FR-CPY-002.
@JsonSerializable()
class CopySettingsInput {
  const CopySettingsInput({
    this.mediaSize,
    this.scalePercent,
    this.tray,
    this.collate = true,
    this.colorMode = CopySettingsInputColorMode.auto,
    this.copies = 1,
    this.method = CopySettingsInputMethod.scanThenPrint,
    this.outputDuplex = DuplexMode.oneSided,
    this.scaling = CopySettingsInputScaling.actual,
    this.sourceDuplex = false,
  });

  factory CopySettingsInput.fromJson(Map<String, Object?> json) =>
      _$CopySettingsInputFromJson(json);

  final bool collate;
  @JsonKey(name: 'color_mode')
  final CopySettingsInputColorMode colorMode;
  final int copies;
  @JsonKey(name: 'media_size')
  final String? mediaSize;
  final CopySettingsInputMethod method;
  @JsonKey(name: 'output_duplex')
  final DuplexMode outputDuplex;
  @JsonKey(name: 'scale_percent')
  final int? scalePercent;
  final CopySettingsInputScaling scaling;
  @JsonKey(name: 'source_duplex')
  final bool sourceDuplex;
  final String? tray;

  Map<String, Object?> toJson() => _$CopySettingsInputToJson(this);
}
