// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_job_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageJobRead _$PageJobReadFromJson(Map<String, dynamic> json) => PageJobRead(
  items: (json['items'] as List<dynamic>)
      .map((e) => JobRead.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextCursor: json['next_cursor'] as String?,
);

Map<String, dynamic> _$PageJobReadToJson(PageJobRead instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'next_cursor': ?instance.nextCursor,
    };
