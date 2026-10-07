// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'copy_job_read.dart';
import 'copy_settings_output.dart';
import 'execution_mode.dart';
import 'job_status.dart';
import 'print_job_read.dart';
import 'print_settings_output.dart';
import 'scan_job_read.dart';
import 'scan_settings_output.dart';

part 'job_read.g.dart';

@JsonSerializable(createFactory: false)
sealed class JobRead {
  const JobRead();

  factory JobRead.fromJson(Map<String, dynamic> json) =>
      JobReadSealedDeserializer.tryDeserialize(json);

  Map<String, dynamic> toJson();
}

extension JobReadSealedDeserializer on JobRead {
  static JobRead tryDeserialize(
    Map<String, dynamic> json, {
    String key = 'type',
    Map<Type, Object?>? mapping,
  }) {
    final mappingFallback = const <Type, Object?>{
      JobReadCopyJobRead: 'copy',
      JobReadPrintJobRead: 'print',
      JobReadScanJobRead: 'scan',
    };
    final value = json[key];
    final effective = mapping ?? mappingFallback;
    return switch (value) {
      _ when value == effective[JobReadCopyJobRead] =>
        JobReadCopyJobRead.fromJson(json),
      _ when value == effective[JobReadPrintJobRead] =>
        JobReadPrintJobRead.fromJson(json),
      _ when value == effective[JobReadScanJobRead] =>
        JobReadScanJobRead.fromJson(json),
      _ => throw FormatException(
        'Unknown discriminator value "${json[key]}" for JobRead',
      ),
    };
  }
}

@JsonSerializable()
class JobReadCopyJobRead extends JobRead implements CopyJobRead {
  @override
  final DateTime? completedAt;
  @override
  final String? connectionId;
  @override
  final String? connectionType;
  @override
  final DateTime createdAt;
  @override
  final String? deviceId;
  @override
  final String? documentId;
  @override
  final String? errorCode;
  @override
  final String? errorMessage;
  @override
  final ExecutionMode executionMode;
  @override
  final bool fallbackOccurred;
  @override
  final String id;
  @override
  final String organizationId;
  @override
  final String? outputDocumentId;
  @override
  final int? pageCount;
  @override
  final String printerId;
  @override
  final String? printerJobRef;
  @override
  final String? retryOfJobId;
  @override
  final CopySettingsOutput settings;
  @override
  final DateTime? startedAt;
  @override
  final JobStatus status;
  @override
  final DateTime submittedAt;
  @override
  final String? title;
  @override
  final String type;
  @override
  final DateTime updatedAt;
  @override
  final String? userId;

  const JobReadCopyJobRead({
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

  factory JobReadCopyJobRead.fromJson(Map<String, dynamic> json) =>
      _$JobReadCopyJobReadFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$JobReadCopyJobReadToJson(this);
}

@JsonSerializable()
class JobReadPrintJobRead extends JobRead implements PrintJobRead {
  @override
  final DateTime? completedAt;
  @override
  final String? connectionId;
  @override
  final String? connectionType;
  @override
  final DateTime createdAt;
  @override
  final String? deviceId;
  @override
  final String? documentId;
  @override
  final String? errorCode;
  @override
  final String? errorMessage;
  @override
  final ExecutionMode executionMode;
  @override
  final bool fallbackOccurred;
  @override
  final String id;
  @override
  final String organizationId;
  @override
  final String? outputDocumentId;
  @override
  final int? pageCount;
  @override
  final String printerId;
  @override
  final String? printerJobRef;
  @override
  final String? retryOfJobId;
  @override
  final PrintSettingsOutput settings;
  @override
  final DateTime? startedAt;
  @override
  final JobStatus status;
  @override
  final DateTime submittedAt;
  @override
  final String? title;
  @override
  final String type;
  @override
  final DateTime updatedAt;
  @override
  final String? userId;

  const JobReadPrintJobRead({
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

  factory JobReadPrintJobRead.fromJson(Map<String, dynamic> json) =>
      _$JobReadPrintJobReadFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$JobReadPrintJobReadToJson(this);
}

@JsonSerializable()
class JobReadScanJobRead extends JobRead implements ScanJobRead {
  @override
  final DateTime? completedAt;
  @override
  final String? connectionId;
  @override
  final String? connectionType;
  @override
  final DateTime createdAt;
  @override
  final String? deviceId;
  @override
  final String? documentId;
  @override
  final String? errorCode;
  @override
  final String? errorMessage;
  @override
  final ExecutionMode executionMode;
  @override
  final bool fallbackOccurred;
  @override
  final String id;
  @override
  final String organizationId;
  @override
  final String? outputDocumentId;
  @override
  final int? pageCount;
  @override
  final String printerId;
  @override
  final String? printerJobRef;
  @override
  final String? retryOfJobId;
  @override
  final ScanSettingsOutput settings;
  @override
  final DateTime? startedAt;
  @override
  final JobStatus status;
  @override
  final DateTime submittedAt;
  @override
  final String? title;
  @override
  final String type;
  @override
  final DateTime updatedAt;
  @override
  final String? userId;

  const JobReadScanJobRead({
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

  factory JobReadScanJobRead.fromJson(Map<String, dynamic> json) =>
      _$JobReadScanJobReadFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$JobReadScanJobReadToJson(this);
}
