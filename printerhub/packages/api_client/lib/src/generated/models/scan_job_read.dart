// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'execution_mode.dart';
import 'job_read.dart';
import 'job_status.dart';
import 'scan_settings_output.dart';

part 'scan_job_read.g.dart';

@JsonSerializable()
class ScanJobRead {
  const ScanJobRead({
    required this.completedAt,
    required this.connectionId,
    required this.connectionType,
    required this.createdAt,
    required this.deviceId,
    required this.documentId,
    required this.errorCode,
    required this.errorMessage,
    required this.executionMode,
    required this.fallbackOccurred,
    required this.id,
    required this.organizationId,
    required this.outputDocumentId,
    required this.pageCount,
    required this.printerId,
    required this.printerJobRef,
    required this.retryOfJobId,
    required this.settings,
    required this.startedAt,
    required this.status,
    required this.submittedAt,
    required this.title,
    required this.type,
    required this.updatedAt,
    required this.userId,
  });

  factory ScanJobRead.fromJson(Map<String, Object?> json) =>
      _$ScanJobReadFromJson(json);

  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'connection_id')
  final String? connectionId;
  @JsonKey(name: 'connection_type')
  final String? connectionType;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'document_id')
  final String? documentId;
  @JsonKey(name: 'error_code')
  final String? errorCode;
  @JsonKey(name: 'error_message')
  final String? errorMessage;
  @JsonKey(name: 'execution_mode')
  final ExecutionMode executionMode;

  /// True when the job moved to a different connection after its first attempt
  @JsonKey(name: 'fallback_occurred')
  final bool fallbackOccurred;
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'output_document_id')
  final String? outputDocumentId;
  @JsonKey(name: 'page_count')
  final int? pageCount;
  @JsonKey(name: 'printer_id')
  final String printerId;
  @JsonKey(name: 'printer_job_ref')
  final String? printerJobRef;
  @JsonKey(name: 'retry_of_job_id')
  final String? retryOfJobId;
  final ScanSettingsOutput settings;
  @JsonKey(name: 'started_at')
  final DateTime? startedAt;
  final JobStatus status;
  @JsonKey(name: 'submitted_at')
  final DateTime submittedAt;
  final String? title;
  final String type;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'user_id')
  final String? userId;

  Map<String, Object?> toJson() => _$ScanJobReadToJson(this);
}
