import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';

const _notifications = '/api/v1/notifications';

void main() {
  late FakeApi api;
  late NotificationsRepository repository;
  late int changes;

  setUp(() {
    api = FakeApi((request) async {
      final path = request.path.replaceFirst(_notifications, '');
      if (path == '/unread-count') {
        return const FakeResponse(200, {'unread': 3});
      }
      if (path == '/read-all') return const FakeResponse(204);
      if (path.endsWith('/read')) {
        return FakeResponse(
          200,
          notificationBody(readAt: '2026-10-07T11:00:00Z'),
        );
      }
      return FakeResponse(200, {
        'items': [
          notificationBody(),
          notificationBody(
            id: 'notification-2',
            type: 'organization.invitation',
            title: 'You were invited',
            body: 'Acme invited you.',
            data: const {'invitation_id': 'invitation-1'},
            readAt: '2026-10-07T09:00:00Z',
          ),
        ],
        'next_cursor': 'next-page',
      });
    });
    final client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: InMemoryTokenStore(),
      httpClientAdapter: api,
    );
    addTearDown(client.close);
    repository = NotificationsRepository(client: client);
    changes = 0;
    final watching = repository.changes.listen((_) => changes++);
    addTearDown(watching.cancel);
  });

  test('lists what the account was told, newest first', () async {
    final page = await repository.list();

    expect(api.requests.single.path, _notifications);
    expect(
      api.requests.single.queryParameters,
      containsPair('unread_only', false),
    );
    expect(page.next, 'next-page');
    final [job, invitation] = page.notifications;
    expect(job.type, 'job.completed');
    expect(job.title, 'Print finished');
    expect(job.body, contains('Report.pdf'));
    expect(job.jobId, 'job-1');
    expect(job.organizationId, 'org-1');
    expect(job.invitationId, isNull);
    expect(job.isRead, isFalse);
    expect(job.createdAt, DateTime.utc(2026, 10, 7, 10));
    expect(invitation.invitationId, 'invitation-1');
    expect(invitation.organizationId, isNull);
    expect(invitation.jobId, isNull);
    expect(invitation.isRead, isTrue);
  });

  test('lists only the unread, and reads on', () async {
    await repository.list(unreadOnly: true, cursor: 'next-page');

    final asked = api.requests.single.queryParameters;
    expect(asked['unread_only'], isTrue);
    expect(asked['cursor'], 'next-page');
  });

  test('counts the unread', () async {
    expect(await repository.unreadCount(), 3);
    expect(api.requests.single.path, '$_notifications/unread-count');
    expect(changes, 0);
  });

  test('marks one read, and says the count has changed', () async {
    final read = await repository.markRead('notification-1');
    await pumpEventQueue();

    expect(api.requests.single.method, 'POST');
    expect(api.requests.single.path, '$_notifications/notification-1/read');
    expect(read.isRead, isTrue);
    expect(changes, 1);
  });

  test('marks everything read, and says the count has changed', () async {
    await repository.markAllRead();
    await pumpEventQueue();

    expect(api.requests.single.path, '$_notifications/read-all');
    expect(changes, 1);
  });

  test('a notification compares by value', () {
    AppNotification make() => AppNotification.fromApi(
      NotificationRead.fromJson(notificationBody().cast()),
    );

    expect(make(), make());
  });
}
