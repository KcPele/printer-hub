import 'package:api_client/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/notifications/notifications.dart';
import 'package:printerhub/session/session.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';
const _other = '0198c0de-0000-7000-8000-00000000000c';

void main() {
  late TestBackend backend;
  late MockGoRouter router;

  Map<String, String> about(String organizationId) => {
    'job_id': 'job-1',
    'organization_id': organizationId,
  };

  setUp(() async {
    backend = TestBackend()
      ..workspaces = [
        organizationBody(),
        organizationBody(id: _other, name: 'Beta'),
      ]
      ..notificationList = [
        notificationBody(
          id: 'notification-4',
          type: 'job.failed',
          title: 'Print failed',
          body: 'Report.pdf could not be printed on Front desk.',
          data: about(_org),
        ),
        notificationBody(
          id: 'notification-3',
          type: 'organization.invitation',
          title: 'You were invited',
          body: 'Beta invited you to join.',
          data: const {'invitation_id': 'invitation-1'},
        ),
        notificationBody(
          id: 'notification-2',
          type: 'job.cancelled',
          title: 'Print cancelled',
          data: about(_other),
        ),
        notificationBody(
          type: 'scan.ready',
          title: 'Scan ready',
          data: about('a workspace since left'),
          readAt: '2026-10-07T09:00:00Z',
        ),
      ];
    router = recordingRouter();
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  /// The dots that mark what has not been read.
  final unreadDots = find.byWidgetPredicate(
    (widget) =>
        widget is Semantics && widget.properties.label == 'Not read yet',
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpApp(
      const NotificationsPage(),
      backend: backend,
      router: router,
    );
    await tester.pumpAndSettle();
  }

  group('NotificationsPage', () {
    testWidgets('says what will appear, before anything has', (tester) async {
      backend.notificationList = [];

      await pump(tester);

      expect(find.text('Nothing to tell you yet'), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('lists what the account was told, and marks the unread', (
      tester,
    ) async {
      backend.notificationList = [
        ...backend.notificationList,
        notificationBody(
          id: 'notification-0',
          type: 'something.new',
          title: 'Something new',
          readAt: '2026-10-07T09:00:00Z',
        ),
        notificationBody(id: 'notification-00', readAt: '2026-10-07T09:00:00Z'),
      ];
      await pump(tester);

      expect(find.text('Print failed'), findsOneWidget);
      expect(
        find.text('Report.pdf could not be printed on Front desk.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
      expect(unreadDots, findsNWidgets(3));

      await tester.scrollUntilVisible(find.text('Print finished'), 200);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('opens the job a notification is about, and reads it', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Print failed'));
      await tester.pumpAndSettle();

      verify(() => router.go(AppRoutes.job('job-1'))).called(1);
      expect(backend.notificationList.first['read_at'], isNotNull);
      expect(unreadDots, findsNWidgets(2));
    });

    testWidgets('moves to the workspace a job was in before opening it', (
      tester,
    ) async {
      await pump(tester);
      final session = BlocProvider.of<SessionCubit>(
        tester.element(find.byType(NotificationsView)),
      );
      expect(session.state.organization!.id, _org);

      await tester.tap(find.text('Print cancelled'));
      await tester.pumpAndSettle();

      expect(session.state.organization!.id, _other);
      verify(() => router.go(AppRoutes.job('job-1'))).called(1);
    });

    testWidgets('only reads a notification that leads nowhere', (tester) async {
      await pump(tester);

      // An invitation has no job, and this job's workspace has been left.
      await tester.tap(find.text('You were invited'));
      await tester.tap(find.text('Scan ready'));
      await tester.pumpAndSettle();

      verifyNever(() => router.go(any(), extra: any(named: 'extra')));
      expect(backend.notificationList[1]['read_at'], isNotNull);
    });

    testWidgets('marks everything read', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(unreadDots, findsNothing);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('says when marking them read did not work', (tester) async {
      await pump(tester);
      backend.offline = true;

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Can't reach PrinterHub"), findsOneWidget);
      expect(unreadDots, findsNWidgets(3));
    });

    testWidgets('reads earlier notifications when asked', (tester) async {
      backend.notificationPageSize = 3;
      await pump(tester);
      expect(find.text('Scan ready'), findsNothing);

      await tester.scrollUntilVisible(find.text('Show earlier'), 200);
      await tester.tap(find.text('Show earlier'));
      await tester.pumpAndSettle();

      expect(find.text('Scan ready'), findsOneWidget);
    });

    testWidgets('reads again when pulled down', (tester) async {
      await pump(tester);
      backend.notificationList = [
        notificationBody(id: 'notification-5', title: 'Copy finished'),
        ...backend.notificationList,
      ];

      await tester.drag(find.text('Print failed'), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.text('Copy finished'), findsOneWidget);
    });

    testWidgets('says why the list cannot be read, and tries again', (
      tester,
    ) async {
      backend.offline = true;
      await pump(tester);

      expect(find.text('Your notifications could not be read'), findsOneWidget);

      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Print failed'), findsOneWidget);
    });
  });
}
