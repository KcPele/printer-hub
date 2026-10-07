// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_priority_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionPriorityUpdate _$ConnectionPriorityUpdateFromJson(
  Map<String, dynamic> json,
) => ConnectionPriorityUpdate(
  connectionIds: (json['connection_ids'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$ConnectionPriorityUpdateToJson(
  ConnectionPriorityUpdate instance,
) => <String, dynamic>{'connection_ids': instance.connectionIds};
