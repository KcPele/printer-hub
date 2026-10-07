// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'readiness.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Readiness _$ReadinessFromJson(Map<String, dynamic> json) => Readiness(
  database: ReadinessDatabase.fromJson(json['database'] as String),
  redis: ReadinessRedis.fromJson(json['redis'] as String),
  status: ReadinessStatus.fromJson(json['status'] as String),
);

Map<String, dynamic> _$ReadinessToJson(Readiness instance) => <String, dynamic>{
  'database': instance.database.toJson(),
  'redis': instance.redis.toJson(),
  'status': instance.status.toJson(),
};
