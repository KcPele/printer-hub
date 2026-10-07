import 'package:go_router/go_router.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/activity/activity.dart';
import 'package:printerhub/gallery/gallery.dart';
import 'package:printerhub/home/home.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/settings/settings.dart';
import 'package:printerhub/shell/shell.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/welcome/welcome.dart';

/// Where each screen lives.
abstract final class AppRoutes {
  static const String welcome = '/welcome';
  static const String home = '/home';
  static const String printers = '/printers';
  static const String activity = '/activity';
  static const String settings = '/settings';
  static const String theme = '/settings/theme';
  static const String gallery = '/settings/gallery';
}

/// Builds the app's router.
///
/// A new install is sent to the welcome screens, and is not sent there
/// again once they have been seen. [initialLocation] is for tests.
GoRouter createAppRouter({
  required PreferencesRepository preferencesRepository,
  String initialLocation = AppRoutes.home,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      final welcomed = preferencesRepository.onboardingCompleted;
      final atWelcome = state.matchedLocation == AppRoutes.welcome;
      if (!welcomed && !atWelcome) return AppRoutes.welcome;
      if (welcomed && atWelcome) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomePage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.printers,
                builder: (context, state) => const PrintersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.activity,
                builder: (context, state) => const ActivityPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'theme',
                    builder: (context, state) => const ThemePage(),
                  ),
                  GoRoute(
                    path: 'gallery',
                    builder: (context, state) => const GalleryPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
