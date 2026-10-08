import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';

/// Something the account was told.
class AppNotification extends Equatable {
  const new({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const {},
    this.organizationId,
    this.readAt,
  });

  factory fromApi(NotificationRead notification) {
    return AppNotification(
      id: notification.id,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      createdAt: notification.createdAt,
      data: notification.data,
      organizationId: notification.organizationId,
      readAt: notification.readAt,
    );
  }

  final String id;

  /// What it is about: `job.completed`, `job.failed`, `job.cancelled`,
  /// `scan.ready`, or `organization.invitation`.
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;

  /// The identifiers needed to open the right screen.
  final Map<String, String> data;

  /// The workspace it happened in, when it happened in one.
  final String? organizationId;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  /// The job it is about, for a notification about a job.
  String? get jobId => data['job_id'];

  /// The invitation it is about, for an invitation.
  String? get invitationId => data['invitation_id'];

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    body,
    createdAt,
    data,
    organizationId,
    readAt,
  ];
}

/// What the signed-in account has been told, and which of it was read.
class NotificationsRepository {
  new({required this._client});

  final PrinterHubClient _client;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires when something was marked read: the number unread is no longer
  /// what it was.
  Stream<void> get changes => _changes.stream;

  /// A page of notifications, newest first. Pass [cursor] from the page
  /// before to read on.
  Future<({List<AppNotification> notifications, String? next})> list({
    bool unreadOnly = false,
    String? cursor,
  }) async {
    final page = await apiCall(
      () => _client.api.notifications.listNotifications(
        unreadOnly: unreadOnly,
        cursor: cursor,
      ),
    );
    return (
      notifications: page.items.map(AppNotification.fromApi).toList(),
      next: page.nextCursor,
    );
  }

  /// How many have not been read.
  Future<int> unreadCount() async {
    final count = await apiCall(_client.api.notifications.getUnreadCount);
    return count.unread;
  }

  Future<AppNotification> markRead(String notificationId) async {
    final read = AppNotification.fromApi(
      await apiCall(
        () =>
            _client.api.notifications.markRead(notificationId: notificationId),
      ),
    );
    _changes.add(null);
    return read;
  }

  Future<void> markAllRead() async {
    await apiCall(_client.api.notifications.markAllRead);
    _changes.add(null);
  }
}
