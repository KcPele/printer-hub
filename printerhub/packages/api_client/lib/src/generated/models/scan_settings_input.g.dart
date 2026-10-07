// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_settings_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanSettingsInput _$ScanSettingsInputFromJson(Map<String, dynamic> json) =>
    ScanSettingsInput(
      mediaSize: json['media_size'] as String?,
      colorMode: json['color_mode'] == null
          ? ScanSettingsInputColorMode.auto
          : ScanSettingsInputColorMode.fromJson(json['color_mode'] as String),
      duplex: json['duplex'] as bool? ?? false,
      format: json['format'] == null
          ? ScanSettingsInputFormat.undefined0
          : ScanSettingsInputFormat.fromJson(json['format'] as String),
      resolutionDpi: (json['resolution_dpi'] as num?)?.toInt() ?? 300,
      searchablePdf: json['searchable_pdf'] as bool? ?? false,
      source: json['source'] == null
          ? ScanSettingsInputSource.auto
          : ScanSettingsInputSource.fromJson(json['source'] as String),
    );

Map<String, dynamic> _$ScanSettingsInputToJson(ScanSettingsInput instance) =>
    <String, dynamic>{
      'color_mode': instance.colorMode,
      'duplex': instance.duplex,
      'format': instance.format,
      'media_size': instance.mediaSize,
      'resolution_dpi': instance.resolutionDpi,
      'searchable_pdf': instance.searchablePdf,
      'source': instance.source,
    };
