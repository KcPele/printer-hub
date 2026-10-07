// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consumable_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConsumableInput _$ConsumableInputFromJson(Map<String, dynamic> json) =>
    ConsumableInput(
      kind: json['kind'] as String,
      name: json['name'] as String,
      state: json['state'] == null
          ? ConsumableInputState.unknown
          : ConsumableInputState.fromJson(json['state'] as String),
      color: json['color'] as String?,
      levelPercent: (json['level_percent'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ConsumableInputToJson(ConsumableInput instance) =>
    <String, dynamic>{
      'color': instance.color,
      'kind': instance.kind,
      'level_percent': instance.levelPercent,
      'name': instance.name,
      'state': instance.state,
    };
