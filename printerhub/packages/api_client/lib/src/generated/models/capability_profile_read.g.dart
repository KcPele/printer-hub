// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'capability_profile_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CapabilityProfileRead _$CapabilityProfileReadFromJson(
  Map<String, dynamic> json,
) => CapabilityProfileRead(
  capabilities: PrinterCapabilitiesOutput.fromJson(
    json['capabilities'] as Map<String, dynamic>,
  ),
  displayName: json['display_name'] as String,
  id: json['id'] as String,
  manufacturer: json['manufacturer'] as String,
  modelPatterns: (json['model_patterns'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  notes: (json['notes'] as List<dynamic>).map((e) => e as String).toList(),
  optionalFeatures: (json['optional_features'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  setupTips: (json['setup_tips'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  summary: json['summary'] as String?,
  updatedAt: DateTime.parse(json['updated_at'] as String),
  version: (json['version'] as num).toInt(),
  category: json['category'] == null
      ? ProfileCategory.officeMultifunction
      : ProfileCategory.fromJson(json['category'] as String),
  popularity: (json['popularity'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CapabilityProfileReadToJson(
  CapabilityProfileRead instance,
) => <String, dynamic>{
  'capabilities': instance.capabilities.toJson(),
  'category': instance.category.toJson(),
  'display_name': instance.displayName,
  'id': instance.id,
  'manufacturer': instance.manufacturer,
  'model_patterns': instance.modelPatterns,
  'notes': instance.notes,
  'optional_features': instance.optionalFeatures,
  'popularity': instance.popularity,
  'setup_tips': instance.setupTips,
  'summary': ?instance.summary,
  'updated_at': instance.updatedAt.toIso8601String(),
  'version': instance.version,
};
