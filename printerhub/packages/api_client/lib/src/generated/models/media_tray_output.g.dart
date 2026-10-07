// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_tray_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaTrayOutput _$MediaTrayOutputFromJson(Map<String, dynamic> json) =>
    MediaTrayOutput(
      id: json['id'] as String,
      mediaSize: json['media_size'] as String?,
      mediaType: json['media_type'] as String?,
      name: json['name'] as String,
    );

Map<String, dynamic> _$MediaTrayOutputToJson(MediaTrayOutput instance) =>
    <String, dynamic>{
      'id': instance.id,
      'media_size': instance.mediaSize,
      'media_type': instance.mediaType,
      'name': instance.name,
    };
