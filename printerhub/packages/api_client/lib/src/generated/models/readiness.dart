// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'readiness_database.dart';
import 'readiness_redis.dart';
import 'readiness_status.dart';

part 'readiness.g.dart';

@JsonSerializable()
class Readiness {
  const Readiness({
    required this.database,
    required this.redis,
    required this.status,
  });

  factory Readiness.fromJson(Map<String, Object?> json) =>
      _$ReadinessFromJson(json);

  final ReadinessDatabase database;
  final ReadinessRedis redis;
  final ReadinessStatus status;

  Map<String, Object?> toJson() => _$ReadinessToJson(this);
}
