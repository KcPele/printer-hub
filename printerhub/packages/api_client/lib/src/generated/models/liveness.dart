// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'liveness.g.dart';

@JsonSerializable()
class Liveness {
  const Liveness({this.status = 'ok'});

  factory Liveness.fromJson(Map<String, Object?> json) =>
      _$LivenessFromJson(json);

  final String status;

  Map<String, Object?> toJson() => _$LivenessToJson(this);
}
