// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'execution_mode.dart';
import 'job_create.dart';
import 'print_settings_input.dart';

part 'print_job_create.g.dart';

@JsonSerializable()
class PrintJobCreate {
  const PrintJobCreate({
    required this.printerId,
    required this.type,
    this.executionMode = ExecutionMode.local,
    this.connectionId,
    this.documentId,
    this.id,
    this.pageCount,
    this.settings,
    this.submittedAt,
    this.title,
  });

  factory PrintJobCreate.fromJson(Map<String, Object?> json) =>
      _$PrintJobCreateFromJson(json);

  /// The connection the client intends to use first
  @JsonKey(name: 'connection_id')
  final String? connectionId;
  @JsonKey(name: 'document_id')
  final String? documentId;
  @JsonKey(name: 'execution_mode')
  final ExecutionMode executionMode;

  /// Client-generated ID, so a job created offline keeps its identity
  final String? id;
  @JsonKey(name: 'page_count')
  final int? pageCount;
  @JsonKey(name: 'printer_id')
  final String printerId;
  final PrintSettingsInput? settings;

  /// When the user submitted the job, if earlier than now
  @JsonKey(name: 'submitted_at')
  final DateTime? submittedAt;
  final String? title;
  final String type;

  Map<String, Object?> toJson() => _$PrintJobCreateToJson(this);
}
