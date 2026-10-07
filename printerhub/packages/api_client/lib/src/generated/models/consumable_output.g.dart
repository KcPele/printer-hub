// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consumable_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConsumableOutput _$ConsumableOutputFromJson(Map<String, dynamic> json) =>
    ConsumableOutput(
      color: json['color'] as String?,
      kind: json['kind'] as String,
      levelPercent: (json['level_percent'] as num?)?.toInt(),
      name: json['name'] as String,
      state: json['state'] == null
          ? ConsumableOutputState.unknown
          : ConsumableOutputState.fromJson(json['state'] as String),
    );

Map<String, dynamic> _$ConsumableOutputToJson(ConsumableOutput instance) =>
    <String, dynamic>{
      'color': ?instance.color,
      'kind': instance.kind,
      'level_percent': ?instance.levelPercent,
      'name': instance.name,
      'state': instance.state.toJson(),
    };
