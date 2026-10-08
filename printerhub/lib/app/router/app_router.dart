import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/account/account.dart';
import 'package:printerhub/activity/activity.dart';
import 'package:printerhub/auth/auth.dart';
import 'package:printerhub/catalogue/catalogue.dart';
import 'package:printerhub/gallery/gallery.dart';
import 'package:printerhub/home/home.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/settings/settings.dart';
import 'package:printerhub/shell/shell.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/welcome/welcome.dart';

/// Where each screen lives.
abstract final class AppRoutes {
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String loading = '/loading';
  static const String newWorkspace = '/workspace/new';
  static const String verifyEmail = '/verify-email';
  static const String home = '/home';
  static const String printers = '/printers';
  static const String addPrinter = '/printers/add';
  static const String catalogue = '/printers/catalogue';

  /// The page of one printer.
  static String printer(String id) => '/printers/$id';
  static const String activity = '/activity';
  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String changePassword = '/settings/password';
  static const String devices = '/settings/devices';
  static const String deleteAccount = '/settings/delete-account';
  static const String theme = '/settings/theme';
  static const String gallery = '/settings/gallery';

  /// The screens a signed-out person may be on.
  static const Set<String> signedOut = {
    signIn,
    register,
    forgotPassword,
    resetPassword,
  };

  /// The screens passed through on the way into the app.
  static const Set<String> entry = {
    welcome,
    loading,
    newWorkspace,
    ...signedOut,
  };
}

/// Where someone at [location] belongs, or null when they may stay.
///
/// A new install sees the welcome screens once. After that the session
/// decides: sign in, wait for the workspaces, name a workspace, or use the
/// app.
String? redirectFor({
  required bool welcomed,
  required SessionStage stage,
  required String location,
}) {
  String? only(String route) => location == route ? null : route;

  if (!welcomed) return only(AppRoutes.welcome);
  return switch (stage) {
    SessionStage.signedOut =>
      AppRoutes.signedOut.contains(location) ? null : AppRoutes.signIn,
    SessionStage.loading || SessionStage.failed => only(AppRoutes.loading),
    SessionStage.needsWorkspace => only(AppRoutes.newWorkspace),
    SessionStage.ready =>
      AppRoutes.entry.contains(location) ? AppRoutes.home : null,
  };
}

/// Builds the app's router. [refresh] makes it apply [redirectFor] again
/// when the session changes. [initialLocation] is for tests.
GoRouter createAppRouter({
  required PreferencesRepository preferencesRepository,
  required SessionCubit sessionCubit,
  Listenable? refresh,
  String initialLocation = AppRoutes.home,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      welcomed: preferencesRepository.onboardingCompleted,
      stage: sessionCubit.state.stage,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) =>
            ResetPasswordPage(email: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const LoadingPage(),
      ),
      GoRoute(
        path: AppRoutes.newWorkspace,
        builder: (context, state) => const CreateWorkspacePage(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const VerifyEmailPage(),
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
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const AddPrinterPage(),
                  ),
                  GoRoute(
                    path: 'catalogue',
                    builder: (context, state) => const CataloguePage(),
                  ),
                  GoRoute(
                    path: ':printerId',
                    builder: (context, state) => PrinterDetailPage(
                      printerId: state.pathParameters['printerId']!,
                    ),
                  ),
                ],
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
                    path: 'profile',
                    builder: (context, state) => const ProfilePage(),
                  ),
                  GoRoute(
                    path: 'password',
                    builder: (context, state) => const ChangePasswordPage(),
                  ),
                  GoRoute(
                    path: 'devices',
                    builder: (context, state) => const DevicesPage(),
                  ),
                  GoRoute(
                    path: 'delete-account',
                    builder: (context, state) => const DeleteAccountPage(),
                  ),
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
