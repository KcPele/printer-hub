import 'package:go_router/go_router.dart';
import 'package:printerhub/gallery/gallery.dart';
import 'package:printerhub/theme/theme.dart';

/// Where each screen lives.
abstract final class AppRoutes {
  static const String gallery = '/';
  static const String theme = '/settings/theme';
}

/// Builds the app's router. [initialLocation] is for tests.
GoRouter createAppRouter({String initialLocation = AppRoutes.gallery}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.gallery,
        builder: (context, state) => const GalleryPage(),
      ),
      GoRoute(
        path: AppRoutes.theme,
        builder: (context, state) => const ThemePage(),
      ),
    ],
  );
}
