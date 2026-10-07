// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'notification_read.dart';

part 'page_notification_read.g.dart';

@JsonSerializable()
class PageNotificationRead {
  const PageNotificationRead({required this.items, required this.nextCursor});

  factory PageNotificationRead.fromJson(Map<String, Object?> json) =>
      _$PageNotificationReadFromJson(json);

  final List<NotificationRead> items;
  @JsonKey(name: 'next_cursor')
  final String? nextCursor;

  Map<String, Object?> toJson() => _$PageNotificationReadToJson(this);
}
