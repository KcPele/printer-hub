// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'print_settings_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrintSettingsOutput _$PrintSettingsOutputFromJson(Map<String, dynamic> json) =>
    PrintSettingsOutput(
      finishing: (json['finishing'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      mediaSize: json['media_size'] as String?,
      mediaType: json['media_type'] as String?,
      pageRanges: json['page_ranges'] as String?,
      quality: json['quality'] as String?,
      scalePercent: (json['scale_percent'] as num?)?.toInt(),
      tray: json['tray'] as String?,
      collate: json['collate'] as bool? ?? true,
      colorMode: json['color_mode'] == null
          ? PrintSettingsOutputColorMode.auto
          : PrintSettingsOutputColorMode.fromJson(json['color_mode'] as String),
      copies: (json['copies'] as num?)?.toInt() ?? 1,
      duplex: json['duplex'] == null
          ? DuplexMode.oneSided
          : DuplexMode.fromJson(json['duplex'] as String),
      orientation: json['orientation'] == null
          ? PrintSettingsOutputOrientation.auto
          : PrintSettingsOutputOrientation.fromJson(
              json['orientation'] as String,
            ),
      scaling: json['scaling'] == null
          ? PrintSettingsOutputScaling.fit
          : PrintSettingsOutputScaling.fromJson(json['scaling'] as String),
      securePrint: json['secure_print'] as bool? ?? false,
    );

Map<String, dynamic> _$PrintSettingsOutputToJson(
  PrintSettingsOutput instance,
) => <String, dynamic>{
  'collate': instance.collate,
  'color_mode': instance.colorMode.toJson(),
  'copies': instance.copies,
  'duplex': instance.duplex.toJson(),
  'finishing': instance.finishing,
  'media_size': ?instance.mediaSize,
  'media_type': ?instance.mediaType,
  'orientation': instance.orientation.toJson(),
  'page_ranges': ?instance.pageRanges,
  'quality': ?instance.quality,
  'scale_percent': ?instance.scalePercent,
  'scaling': instance.scaling.toJson(),
  'secure_print': instance.securePrint,
  'tray': ?instance.tray,
};
