// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'job_sync_error.g.dart';

@JsonSerializable()
class JobSyncError {
  const JobSyncError({required this.code, required this.detail});

  factory JobSyncError.fromJson(Map<String, Object?> json) =>
      _$JobSyncErrorFromJson(json);

  final String code;
  final String? detail;

  Map<String, Object?> toJson() => _$JobSyncErrorToJson(this);
}
