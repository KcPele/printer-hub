// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'job_status.dart';

part 'job_event_create.g.dart';

/// A state change observed by the client executing the job.
@JsonSerializable()
class JobEventCreate {
  const JobEventCreate({
    required this.status,
    this.connectionId,
    this.detail,
    this.errorCode,
    this.errorMessage,
    this.occurredAt,
    this.outputDocumentId,
    this.pageCount,
    this.printerJobRef,
  });

  factory JobEventCreate.fromJson(Map<String, Object?> json) =>
      _$JobEventCreateFromJson(json);

  /// The connection used for this attempt
  @JsonKey(name: 'connection_id')
  final String? connectionId;
  final dynamic detail;
  @JsonKey(name: 'error_code')
  final String? errorCode;
  @JsonKey(name: 'error_message')
  final String? errorMessage;

  /// When it happened on the device; defaults to now
  @JsonKey(name: 'occurred_at')
  final DateTime? occurredAt;
  @JsonKey(name: 'output_document_id')
  final String? outputDocumentId;
  @JsonKey(name: 'page_count')
  final int? pageCount;
  @JsonKey(name: 'printer_job_ref')
  final String? printerJobRef;
  final JobStatus status;

  Map<String, Object?> toJson() => _$JobEventCreateToJson(this);
}
