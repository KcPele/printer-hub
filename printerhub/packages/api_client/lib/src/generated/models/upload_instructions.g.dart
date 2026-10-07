// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_instructions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadInstructions _$UploadInstructionsFromJson(Map<String, dynamic> json) =>
    UploadInstructions(
      expiresAt: DateTime.parse(json['expires_at'] as String),
      headers: Map<String, String>.from(json['headers'] as Map),
      method: json['method'] as String,
      url: json['url'] as String,
    );

Map<String, dynamic> _$UploadInstructionsToJson(UploadInstructions instance) =>
    <String, dynamic>{
      'expires_at': instance.expiresAt.toIso8601String(),
      'headers': instance.headers,
      'method': instance.method,
      'url': instance.url,
    };
