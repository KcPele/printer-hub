// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'copy_job_create.dart';
import 'copy_settings_input.dart';
import 'execution_mode.dart';
import 'print_job_create.dart';
import 'print_settings_input.dart';
import 'scan_job_create.dart';
import 'scan_settings_input.dart';

part 'job_create.g.dart';

@JsonSerializable(createFactory: false)
sealed class JobCreate {
  const JobCreate();

  factory JobCreate.fromJson(Map<String, dynamic> json) =>
      JobCreateSealedDeserializer.tryDeserialize(json);

  Map<String, dynamic> toJson();
}

extension JobCreateSealedDeserializer on JobCreate {
  static JobCreate tryDeserialize(
    Map<String, dynamic> json, {
    String key = 'type',
    Map<Type, Object?>? mapping,
  }) {
    final mappingFallback = const <Type, Object?>{
      JobCreateCopyJobCreate: 'copy',
      JobCreatePrintJobCreate: 'print',
      JobCreateScanJobCreate: 'scan',
    };
    final value = json[key];
    final effective = mapping ?? mappingFallback;
    return switch (value) {
      _ when value == effective[JobCreateCopyJobCreate] =>
        JobCreateCopyJobCreate.fromJson(json),
      _ when value == effective[JobCreatePrintJobCreate] =>
        JobCreatePrintJobCreate.fromJson(json),
      _ when value == effective[JobCreateScanJobCreate] =>
        JobCreateScanJobCreate.fromJson(json),
      _ => throw FormatException(
        'Unknown discriminator value "${json[key]}" for JobCreate',
      ),
    };
  }
}

@JsonSerializable()
class JobCreateCopyJobCreate extends JobCreate implements CopyJobCreate {
  @override
  final String? connectionId;
  @override
  final String? documentId;
  @override
  final ExecutionMode executionMode;
  @override
  final String? id;
  @override
  final int? pageCount;
  @override
  final String printerId;
  @override
  final CopySettingsInput? settings;
  @override
  final DateTime? submittedAt;
  @override
  final String? title;
  @override
  final String type;

  const JobCreateCopyJobCreate({
    required this.connectionId,
    required this.documentId,
    required this.executionMode,
    required this.id,
    required this.pageCount,
    required this.printerId,
    required this.settings,
    required this.submittedAt,
    required this.title,
    required this.type,
  });

  factory JobCreateCopyJobCreate.fromJson(Map<String, dynamic> json) =>
      _$JobCreateCopyJobCreateFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$JobCreateCopyJobCreateToJson(this);
}

@JsonSerializable()
class JobCreatePrintJobCreate extends JobCreate implements PrintJobCreate {
  @override
  final String? connectionId;
  @override
  final String? documentId;
  @override
  final ExecutionMode executionMode;
  @override
  final String? id;
  @override
  final int? pageCount;
  @override
  final String printerId;
  @override
  final PrintSettingsInput? settings;
  @override
  final DateTime? submittedAt;
  @override
  final String? title;
  @override
  final String type;

  const JobCreatePrintJobCreate({
    required this.connectionId,
    required this.documentId,
    required this.executionMode,
    required this.id,
    required this.pageCount,
    required this.printerId,
    required this.settings,
    required this.submittedAt,
    required this.title,
    required this.type,
  });

  factory JobCreatePrintJobCreate.fromJson(Map<String, dynamic> json) =>
      _$JobCreatePrintJobCreateFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$JobCreatePrintJobCreateToJson(this);
}

@JsonSerializable()
class JobCreateScanJobCreate extends JobCreate implements ScanJobCreate {
  @override
  final String? connectionId;
  @override
  final String? documentId;
  @override
  final ExecutionMode executionMode;
  @override
  final String? id;
  @override
  final int? pageCount;
  @override
  final String printerId;
  @override
  final ScanSettingsInput? settings;
  @override
  final DateTime? submittedAt;
  @override
  final String? title;
  @override
  final String type;

  const JobCreateScanJobCreate({
    required this.connectionId,
    required this.documentId,
    required this.executionMode,
    required this.id,
    required this.pageCount,
    required this.printerId,
    required this.settings,
    required this.submittedAt,
    required this.title,
    required this.type,
  });

  factory JobCreateScanJobCreate.fromJson(Map<String, dynamic> json) =>
      _$JobCreateScanJobCreateFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$JobCreateScanJobCreateToJson(this);
}
