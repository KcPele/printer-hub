// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_capabilities_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanCapabilitiesInput _$ScanCapabilitiesInputFromJson(
  Map<String, dynamic> json,
) => ScanCapabilitiesInput(
  colorModes: (json['color_modes'] as List<dynamic>?)
      ?.map((e) => ScanColorMode.fromJson(e as String))
      .toList(),
  documentFormats: (json['document_formats'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  maxHeightMm: json['max_height_mm'] as num?,
  maxWidthMm: json['max_width_mm'] as num?,
  resolutionsDpi: (json['resolutions_dpi'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  sources: (json['sources'] as List<dynamic>?)
      ?.map((e) => ScanSource.fromJson(e as String))
      .toList(),
  adfDuplex: json['adf_duplex'] as bool? ?? false,
  supported: json['supported'] as bool? ?? false,
);

Map<String, dynamic> _$ScanCapabilitiesInputToJson(
  ScanCapabilitiesInput instance,
) => <String, dynamic>{
  'adf_duplex': instance.adfDuplex,
  'color_modes': instance.colorModes,
  'document_formats': instance.documentFormats,
  'max_height_mm': instance.maxHeightMm,
  'max_width_mm': instance.maxWidthMm,
  'resolutions_dpi': instance.resolutionsDpi,
  'sources': instance.sources,
  'supported': instance.supported,
};
