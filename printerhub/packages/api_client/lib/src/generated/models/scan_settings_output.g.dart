// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_settings_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanSettingsOutput _$ScanSettingsOutputFromJson(Map<String, dynamic> json) =>
    ScanSettingsOutput(
      mediaSize: json['media_size'] as String?,
      colorMode: json['color_mode'] == null
          ? ScanSettingsOutputColorMode.auto
          : ScanSettingsOutputColorMode.fromJson(json['color_mode'] as String),
      duplex: json['duplex'] as bool? ?? false,
      format: json['format'] == null
          ? ScanSettingsOutputFormat.undefined0
          : ScanSettingsOutputFormat.fromJson(json['format'] as String),
      resolutionDpi: (json['resolution_dpi'] as num?)?.toInt() ?? 300,
      searchablePdf: json['searchable_pdf'] as bool? ?? false,
      source: json['source'] == null
          ? ScanSettingsOutputSource.auto
          : ScanSettingsOutputSource.fromJson(json['source'] as String),
    );

Map<String, dynamic> _$ScanSettingsOutputToJson(ScanSettingsOutput instance) =>
    <String, dynamic>{
      'color_mode': instance.colorMode,
      'duplex': instance.duplex,
      'format': instance.format,
      'media_size': instance.mediaSize,
      'resolution_dpi': instance.resolutionDpi,
      'searchable_pdf': instance.searchablePdf,
      'source': instance.source,
    };
