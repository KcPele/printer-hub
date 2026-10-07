import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/app/app.dart';
import 'package:printerhub/session/session.dart';

void main() {
  String? go(
    String location, {
    SessionStage stage = SessionStage.ready,
    bool welcomed = true,
  }) {
    return redirectFor(welcomed: welcomed, stage: stage, location: location);
  }

  group('redirectFor', () {
    test('shows a new install the welcome screens first', () {
      for (final stage in SessionStage.values) {
        expect(
          go(AppRoutes.home, stage: stage, welcomed: false),
          AppRoutes.welcome,
        );
        expect(go(AppRoutes.welcome, stage: stage, welcomed: false), isNull);
      }
    });

    test('keeps a signed-out person on the account screens', () {
      for (final route in AppRoutes.signedOut) {
        expect(go(route, stage: SessionStage.signedOut), isNull);
      }
      for (final route in [
        AppRoutes.home,
        AppRoutes.welcome,
        AppRoutes.theme,
      ]) {
        expect(go(route, stage: SessionStage.signedOut), AppRoutes.signIn);
      }
    });

    test('holds on the loading screen while workspaces load or fail', () {
      for (final stage in [SessionStage.loading, SessionStage.failed]) {
        expect(go(AppRoutes.signIn, stage: stage), AppRoutes.loading);
        expect(go(AppRoutes.home, stage: stage), AppRoutes.loading);
        expect(go(AppRoutes.loading, stage: stage), isNull);
      }
    });

    test('asks a person without a workspace to name one', () {
      expect(
        go(AppRoutes.home, stage: SessionStage.needsWorkspace),
        AppRoutes.newWorkspace,
      );
      expect(
        go(AppRoutes.newWorkspace, stage: SessionStage.needsWorkspace),
        isNull,
      );
    });

    test('moves a ready person off the entry screens and nowhere else', () {
      for (final route in AppRoutes.entry) {
        expect(go(route), AppRoutes.home);
      }
      for (final route in [
        AppRoutes.home,
        AppRoutes.printers,
        AppRoutes.activity,
        AppRoutes.settings,
        AppRoutes.theme,
        AppRoutes.verifyEmail,
      ]) {
        expect(go(route), isNull);
      }
    });
  });
}
