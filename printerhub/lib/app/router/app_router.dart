import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/account/account.dart';
import 'package:printerhub/activity/activity.dart';
import 'package:printerhub/auth/auth.dart';
import 'package:printerhub/catalogue/catalogue.dart';
import 'package:printerhub/copy/copy.dart';
import 'package:printerhub/documents/documents.dart';
import 'package:printerhub/gallery/gallery.dart';
import 'package:printerhub/home/home.dart';
import 'package:printerhub/notifications/notifications.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/settings/settings.dart';
import 'package:printerhub/shell/shell.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/tools/tools.dart';
import 'package:printerhub/welcome/welcome.dart';
import 'package:printerhub/workspace/workspace.dart';

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
  static const String notifications = '/home/notifications';

  /// Scanning with the phone's camera alone, with no printer.
  static const String scan = '/home/scan';

  /// The same screen, begun by choosing pictures: several photos as one
  /// PDF.
  static const String picturesToPdf = '/home/scan/pictures';

  /// Every tool the app has.
  /// Joining PDFs and pictures, or keeping some pages of a PDF: the scan
  /// screen, begun with files.
  static const String filesToPdf = '/home/scan/files';

  static const String scanCode = '/home/tools/code';
  static const String codeSheet = '/home/tools/qr';
  static const String note = '/home/tools/note';
  static const String printable = '/home/tools/printable';
  static const String pagesPerSheet = '/home/tools/per-sheet';

  static const String tools = '/home/tools';

  /// Reading the words in a file.
  static const String extractText = '/home/tools/text';

  /// Photos laid out on a sheet to print.
  static const String photoSheet = '/home/tools/photos';

  /// A PDF's pages as pictures.
  static const String pdfToPictures = '/home/tools/pictures';

  /// A PDF's pages as one tall picture.
  static const String pdfToLongPicture = '/home/tools/long-picture';
  static const String printers = '/printers';
  static const String addPrinter = '/printers/add';
  static const String catalogue = '/printers/catalogue';

  /// The page of one printer.
  static String printer(String id) => '/printers/$id';

  /// Printing a document on one printer.
  static String printOn(String id) => '/printers/$id/print';

  /// Scanning on one printer.
  static String scanOn(String id) => '/printers/$id/scan';

  /// Copying on one printer: its scanner, then its printer.
  static String copyOn(String id) => '/printers/$id/copy';

  /// The ways one printer is reached.
  static String printerConnections(String id) => '/printers/$id/connections';
  static const String activity = '/activity';

  /// The documents the workspace keeps.
  static const String documents = '/activity/documents';

  /// One job from the history.
  static String job(String id) => '/activity/$id';
  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String changePassword = '/settings/password';
  static const String devices = '/settings/devices';
  static const String deleteAccount = '/settings/delete-account';
  static const String workspace = '/settings/workspace';
  static const String members = '/settings/workspace/people';
  static const String workspaceLog = '/settings/workspace/log';
  static const String invitations = '/settings/invitations';
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
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsPage(),
                  ),
                  GoRoute(
                    path: 'scan',
                    builder: (context, state) => const ScanPage(),
                    routes: [
                      GoRoute(
                        path: 'pictures',
                        builder: (context, state) =>
                            const ScanPage(startWithPictures: true),
                      ),
                      GoRoute(
                        path: 'files',
                        builder: (context, state) =>
                            const ScanPage(startWithFiles: true),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'tools',
                    builder: (context, state) => const ToolsPage(),
                    routes: [
                      GoRoute(
                        path: 'text',
                        builder: (context, state) => const ExtractTextPage(),
                      ),
                      GoRoute(
                        path: 'code',
                        builder: (context, state) => const ScanCodePage(),
                      ),
                      GoRoute(
                        path: 'qr',
                        builder: (context, state) => const CodeSheetPage(),
                      ),
                      GoRoute(
                        path: 'note',
                        builder: (context, state) => const NotePage(),
                      ),
                      GoRoute(
                        path: 'printable',
                        builder: (context, state) => const PrintablePage(),
                      ),
                      GoRoute(
                        path: 'per-sheet',
                        builder: (context, state) => const PagesPerSheetPage(),
                      ),
                      GoRoute(
                        path: 'photos',
                        builder: (context, state) => const PhotoSheetPage(),
                      ),
                      GoRoute(
                        path: 'pictures',
                        builder: (context, state) =>
                            const PdfPicturesPage(long: false),
                      ),
                      GoRoute(
                        path: 'long-picture',
                        builder: (context, state) =>
                            const PdfPicturesPage(long: true),
                      ),
                    ],
                  ),
                ],
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
                    routes: [
                      GoRoute(
                        path: 'print',
                        // Arrives with a job to try again, a document to
                        // print, or neither.
                        builder: (context, state) => PrintPage(
                          printerId: state.pathParameters['printerId']!,
                          retryOf: switch (state.extra) {
                            final Job job => job,
                            _ => null,
                          },
                          document: switch (state.extra) {
                            final PickedDocument document => document,
                            _ => null,
                          },
                        ),
                      ),
                      GoRoute(
                        path: 'scan',
                        builder: (context, state) => ScanPage(
                          printerId: state.pathParameters['printerId'],
                        ),
                      ),
                      GoRoute(
                        path: 'copy',
                        builder: (context, state) => CopyPage(
                          printerId: state.pathParameters['printerId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'connections',
                        builder: (context, state) => PrinterConnectionsPage(
                          printerId: state.pathParameters['printerId']!,
                        ),
                      ),
                    ],
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
                routes: [
                  GoRoute(
                    path: 'documents',
                    builder: (context, state) => const DocumentsPage(),
                  ),
                  GoRoute(
                    path: ':jobId',
                    builder: (context, state) => JobPage(
                      jobId: state.pathParameters['jobId']!,
                      known: state.extra as Job?,
                    ),
                  ),
                ],
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
                    path: 'workspace',
                    builder: (context, state) => const WorkspacePage(),
                    routes: [
                      GoRoute(
                        path: 'people',
                        builder: (context, state) => const MembersPage(),
                      ),
                      GoRoute(
                        path: 'log',
                        builder: (context, state) => const WorkspaceLogPage(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'invitations',
                    builder: (context, state) => const InvitationsPage(),
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
