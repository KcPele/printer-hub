// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tray_status_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrayStatusOutput _$TrayStatusOutputFromJson(Map<String, dynamic> json) =>
    TrayStatusOutput(
      id: json['id'] as String,
      mediaSize: json['media_size'] as String?,
      mediaType: json['media_type'] as String?,
      name: json['name'] as String,
      state: json['state'] == null
          ? TrayStatusOutputState.unknown
          : TrayStatusOutputState.fromJson(json['state'] as String),
    );

Map<String, dynamic> _$TrayStatusOutputToJson(TrayStatusOutput instance) =>
    <String, dynamic>{
      'id': instance.id,
      'media_size': ?instance.mediaSize,
      'media_type': ?instance.mediaType,
      'name': instance.name,
      'state': instance.state.toJson(),
    };
