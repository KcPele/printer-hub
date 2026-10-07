// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_notification_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageNotificationRead _$PageNotificationReadFromJson(
  Map<String, dynamic> json,
) => PageNotificationRead(
  items: (json['items'] as List<dynamic>)
      .map((e) => NotificationRead.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextCursor: json['next_cursor'] as String?,
);

Map<String, dynamic> _$PageNotificationReadToJson(
  PageNotificationRead instance,
) => <String, dynamic>{
  'items': instance.items,
  'next_cursor': instance.nextCursor,
};
