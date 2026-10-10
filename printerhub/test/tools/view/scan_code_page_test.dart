import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;
  late List<String> copied;

  setUp(() {
    backend = TestBackend();
    copied = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = call.arguments as Map<Object?, Object?>;
            copied.add(data['text']! as String);
          }
          return null;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await backend.close();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpApp(const ScanCodePage(), backend: backend);
    await tester.pumpAndSettle();
  }

  /// The camera reads [text].
  Future<void> read(WidgetTester tester, String text) async {
    backend.scanCode(text);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the camera until a code is read', (tester) async {
    await pump(tester);

    expect(find.textContaining('Point the camera'), findsOneWidget);
    expect(find.byKey(TestBackend.qrCameraKey), findsOneWidget);
  });

  testWidgets('opens a link, copies it, and goes back for another', (
    tester,
  ) async {
    await pump(tester);
    await read(tester, 'https://example.com/menu');

    expect(find.byKey(TestBackend.qrCameraKey), findsNothing);
    expect(find.text('A link'), findsOneWidget);
    expect(find.text('https://example.com/menu'), findsOneWidget);

    await tester.tap(find.text('Open the link'));
    await tester.pumpAndSettle();
    expect(backend.links.opened, [Uri.parse('https://example.com/menu')]);
    expect(find.textContaining('could open that link'), findsNothing);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, ['https://example.com/menu']);
    expect(find.text('Copied'), findsOneWidget);

    await tester.tap(find.text('Scan another'));
    await tester.pumpAndSettle();
    expect(find.byKey(TestBackend.qrCameraKey), findsOneWidget);
  });

  testWidgets('says when nothing on the phone opens the link', (tester) async {
    backend.links.opens = false;
    await pump(tester);
    await read(tester, 'https://example.com');

    await tester.tap(find.text('Open the link'));
    await tester.pumpAndSettle();

    expect(find.textContaining('could open that link'), findsOneWidget);
  });

  testWidgets('shows a Wi-Fi network and copies its password', (tester) async {
    await pump(tester);
    await read(tester, 'WIFI:T:WPA;S:Office;P:let me in;;');

    expect(find.text('A Wi-Fi network'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Password: let me in'), findsOneWidget);
    expect(find.text('Open the link'), findsNothing);

    await tester.tap(find.text('Copy the password'));
    await tester.pumpAndSettle();
    expect(copied, ['let me in']);
  });

  testWidgets('copies the name of a network with no password', (tester) async {
    await pump(tester);
    await read(tester, 'WIFI:T:nopass;S:Cafe;;');

    expect(find.text('No password'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(copied, ['Cafe']);
  });

  testWidgets('shows a barcode’s number as words', (tester) async {
    await pump(tester);
    await read(tester, '5901234123457');

    expect(find.text('Text'), findsOneWidget);
    expect(find.text('5901234123457'), findsOneWidget);
    expect(find.text('Open the link'), findsNothing);
  });
}
