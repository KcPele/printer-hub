// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_tray_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaTrayInput _$MediaTrayInputFromJson(Map<String, dynamic> json) =>
    MediaTrayInput(
      id: json['id'] as String,
      name: json['name'] as String,
      mediaSize: json['media_size'] as String?,
      mediaType: json['media_type'] as String?,
    );

Map<String, dynamic> _$MediaTrayInputToJson(MediaTrayInput instance) =>
    <String, dynamic>{
      'id': instance.id,
      'media_size': instance.mediaSize,
      'media_type': instance.mediaType,
      'name': instance.name,
    };
