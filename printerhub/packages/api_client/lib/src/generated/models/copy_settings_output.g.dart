// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_settings_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CopySettingsOutput _$CopySettingsOutputFromJson(Map<String, dynamic> json) =>
    CopySettingsOutput(
      mediaSize: json['media_size'] as String?,
      scalePercent: (json['scale_percent'] as num?)?.toInt(),
      tray: json['tray'] as String?,
      collate: json['collate'] as bool? ?? true,
      colorMode: json['color_mode'] == null
          ? CopySettingsOutputColorMode.auto
          : CopySettingsOutputColorMode.fromJson(json['color_mode'] as String),
      copies: (json['copies'] as num?)?.toInt() ?? 1,
      method: json['method'] == null
          ? CopySettingsOutputMethod.scanThenPrint
          : CopySettingsOutputMethod.fromJson(json['method'] as String),
      outputDuplex: json['output_duplex'] == null
          ? DuplexMode.oneSided
          : DuplexMode.fromJson(json['output_duplex'] as String),
      scaling: json['scaling'] == null
          ? CopySettingsOutputScaling.actual
          : CopySettingsOutputScaling.fromJson(json['scaling'] as String),
      sourceDuplex: json['source_duplex'] as bool? ?? false,
    );

Map<String, dynamic> _$CopySettingsOutputToJson(CopySettingsOutput instance) =>
    <String, dynamic>{
      'collate': instance.collate,
      'color_mode': instance.colorMode.toJson(),
      'copies': instance.copies,
      'media_size': ?instance.mediaSize,
      'method': instance.method.toJson(),
      'output_duplex': instance.outputDuplex.toJson(),
      'scale_percent': ?instance.scalePercent,
      'scaling': instance.scaling.toJson(),
      'source_duplex': instance.sourceDuplex,
      'tray': ?instance.tray,
    };
