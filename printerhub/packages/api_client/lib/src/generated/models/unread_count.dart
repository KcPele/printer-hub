// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'unread_count.g.dart';

@JsonSerializable()
class UnreadCount {
  const UnreadCount({required this.unread});

  factory UnreadCount.fromJson(Map<String, Object?> json) =>
      _$UnreadCountFromJson(json);

  final int unread;

  Map<String, Object?> toJson() => _$UnreadCountToJson(this);
}
