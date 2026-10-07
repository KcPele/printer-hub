// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tray_status_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrayStatusInput _$TrayStatusInputFromJson(Map<String, dynamic> json) =>
    TrayStatusInput(
      id: json['id'] as String,
      name: json['name'] as String,
      state: json['state'] == null
          ? TrayStatusInputState.unknown
          : TrayStatusInputState.fromJson(json['state'] as String),
      mediaSize: json['media_size'] as String?,
      mediaType: json['media_type'] as String?,
    );

Map<String, dynamic> _$TrayStatusInputToJson(TrayStatusInput instance) =>
    <String, dynamic>{
      'id': instance.id,
      'media_size': ?instance.mediaSize,
      'media_type': ?instance.mediaType,
      'name': instance.name,
      'state': instance.state.toJson(),
    };
