// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/notification_read.dart';
import '../models/page_notification_read.dart';
import '../models/unread_count.dart';

part 'notifications_client.g.dart';

@RestApi()
abstract class NotificationsClient {
  factory NotificationsClient(Dio dio, {String? baseUrl}) =
      _NotificationsClient;

  /// List Notifications.
  ///
  /// The caller's notifications across all organizations, newest first.
  ///
  /// [cursor] - `next_cursor` from the previous page.
  @GET('/api/v1/notifications')
  Future<PageNotificationRead> listNotifications({
    @Query('cursor') String? cursor,
    @Query('unread_only') bool? unreadOnly = false,
    @Query('limit') int? limit = 50,
  });

  /// Mark All Read
  @POST('/api/v1/notifications/read-all')
  Future<void> markAllRead();

  /// Get Unread Count
  @GET('/api/v1/notifications/unread-count')
  Future<UnreadCount> getUnreadCount();

  /// Mark Read
  @POST('/api/v1/notifications/{notification_id}/read')
  Future<NotificationRead> markRead({
    @Path('notification_id') required String notificationId,
  });
}
