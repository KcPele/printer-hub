// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'job_read.dart';

part 'page_job_read.g.dart';

@JsonSerializable()
class PageJobRead {
  const PageJobRead({required this.items, required this.nextCursor});

  factory PageJobRead.fromJson(Map<String, Object?> json) =>
      _$PageJobReadFromJson(json);

  final List<JobRead> items;
  @JsonKey(name: 'next_cursor')
  final String? nextCursor;

  Map<String, Object?> toJson() => _$PageJobReadToJson(this);
}
