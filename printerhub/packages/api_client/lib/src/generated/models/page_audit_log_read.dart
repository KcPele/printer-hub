// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'audit_log_read.dart';

part 'page_audit_log_read.g.dart';

@JsonSerializable()
class PageAuditLogRead {
  const PageAuditLogRead({required this.items, required this.nextCursor});

  factory PageAuditLogRead.fromJson(Map<String, Object?> json) =>
      _$PageAuditLogReadFromJson(json);

  final List<AuditLogRead> items;
  @JsonKey(name: 'next_cursor')
  final String? nextCursor;

  Map<String, Object?> toJson() => _$PageAuditLogReadToJson(this);
}
