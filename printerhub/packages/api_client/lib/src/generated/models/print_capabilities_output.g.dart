// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'print_capabilities_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrintCapabilitiesOutput _$PrintCapabilitiesOutputFromJson(
  Map<String, dynamic> json,
) => PrintCapabilitiesOutput(
  documentFormats: (json['document_formats'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  duplexModes: (json['duplex_modes'] as List<dynamic>)
      .map((e) => DuplexMode.fromJson(e as String))
      .toList(),
  finishing: (json['finishing'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  maxCopies: (json['max_copies'] as num?)?.toInt(),
  mediaSizes: (json['media_sizes'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  mediaTypes: (json['media_types'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  qualityModes: (json['quality_modes'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  resolutionsDpi: (json['resolutions_dpi'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  trays: (json['trays'] as List<dynamic>)
      .map((e) => MediaTrayOutput.fromJson(e as Map<String, dynamic>))
      .toList(),
  collation: json['collation'] as bool? ?? false,
  color: json['color'] as bool? ?? false,
  securePrint: json['secure_print'] as bool? ?? false,
  supported: json['supported'] as bool? ?? false,
);

Map<String, dynamic> _$PrintCapabilitiesOutputToJson(
  PrintCapabilitiesOutput instance,
) => <String, dynamic>{
  'collation': instance.collation,
  'color': instance.color,
  'document_formats': instance.documentFormats,
  'duplex_modes': instance.duplexModes.map((e) => e.toJson()).toList(),
  'finishing': instance.finishing,
  'max_copies': ?instance.maxCopies,
  'media_sizes': instance.mediaSizes,
  'media_types': instance.mediaTypes,
  'quality_modes': instance.qualityModes,
  'resolutions_dpi': instance.resolutionsDpi,
  'secure_print': instance.securePrint,
  'supported': instance.supported,
  'trays': instance.trays.map((e) => e.toJson()).toList(),
};
