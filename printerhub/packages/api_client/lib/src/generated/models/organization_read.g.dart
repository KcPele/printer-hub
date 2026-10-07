// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganizationRead _$OrganizationReadFromJson(Map<String, dynamic> json) =>
    OrganizationRead(
      createdAt: DateTime.parse(json['created_at'] as String),
      id: json['id'] as String,
      name: json['name'] as String,
      role: Role.fromJson(json['role'] as String),
      settings: OrganizationSettingsOutput.fromJson(
        json['settings'] as Map<String, dynamic>,
      ),
      slug: json['slug'] as String,
    );

Map<String, dynamic> _$OrganizationReadToJson(OrganizationRead instance) =>
    <String, dynamic>{
      'created_at': instance.createdAt.toIso8601String(),
      'id': instance.id,
      'name': instance.name,
      'role': instance.role,
      'settings': instance.settings,
      'slug': instance.slug,
    };
