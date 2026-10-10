import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/activity/job_recovery.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/library/cubit/sync_cubit.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/notifications/notifications.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/printers/widgets/printer_choice_sheet.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/tools/code.dart';
import 'package:printerhub/workspace/workspace.dart';
import 'package:printers_repository/printers_repository.dart';

class App extends StatelessWidget {
  const new({
    required this.preferencesRepository,
    required this.authRepository,
    required this.organizationsRepository,
    required this.printersRepository,
    required this.jobsRepository,
    required this.presetsRepository,
    required this.documentsRepository,
    required this.notificationsRepository,
    required this.finders,
    required this.documents,
    required this.scanSharer,
    required this.scanTextReader,
    required this.pageCamera,
    required this.signatureStore,
    required this.linkOpener,
    required this.library,
    required this.incoming,
    this.keptOrganizations,
    super.key,
  });

  final PreferencesRepository preferencesRepository;
  final AuthRepository authRepository;
  final OrganizationsRepository organizationsRepository;
  final PrintersRepository printersRepository;
  final JobsRepository jobsRepository;
  final PresetsRepository presetsRepository;
  final DocumentsRepository documentsRepository;
  final NotificationsRepository notificationsRepository;

  /// The ways this phone can find a printer.
  final PrinterFinders finders;

  /// The ways this phone gets at documents to print.
  final PrintDocuments documents;

  /// The way this phone hands a finished scan on.
  final ScanSharer scanSharer;

  /// The way this phone reads the words in a scan.
  final ScanTextReader scanTextReader;

  /// The phone's document camera.
  final PageCamera pageCamera;

  /// Where the person's signature is kept on this phone.
  final SignatureStore signatureStore;

  /// Opens a link read from a code in the phone's browser.
  final LinkOpener linkOpener;

  /// What was made on this phone, kept and sent to the account.
  final Library library;

  /// The files other apps hand to this one to print.
  final IncomingDocuments incoming;

  /// The workspace list from the last launch, read before the first frame.
  final List<Organization>? keptOrganizations;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: preferencesRepository),
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: organizationsRepository),
        RepositoryProvider.value(value: printersRepository),
        RepositoryProvider.value(value: jobsRepository),
        RepositoryProvider.value(value: presetsRepository),
        RepositoryProvider(
          create: (_) => JobRecovery(
            jobsRepository: jobsRepository,
            printersRepository: printersRepository,
          ),
        ),
        RepositoryProvider.value(value: documentsRepository),
        RepositoryProvider.value(value: notificationsRepository),
        RepositoryProvider.value(value: finders),
        RepositoryProvider.value(value: documents),
        RepositoryProvider.value(value: scanSharer),
        RepositoryProvider.value(value: scanTextReader),
        RepositoryProvider.value(value: pageCamera),
        RepositoryProvider.value(value: signatureStore),
        RepositoryProvider.value(value: linkOpener),
        RepositoryProvider.value(value: library),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ThemeCubit(
              preferencesRepository: preferencesRepository,
              authRepository: authRepository,
            ),
          ),
          BlocProvider(
            create: (_) {
              final cubit = SessionCubit(
                authRepository: authRepository,
                organizationsRepository: organizationsRepository,
                preferencesRepository: preferencesRepository,
                keptOrganizations: keptOrganizations,
              );
              unawaited(cubit.refresh());
              return cubit;
            },
          ),
          BlocProvider(
            // Created with the app, so the printers are loading while the
            // first screen is drawn.
            lazy: false,
            create: (context) {
              final session = context.read<SessionCubit>();
              final cubit = PrintersCubit(
                printersRepository: printersRepository,
                organizationId: session.state.organization?.id,
                organizationChanges: session.stream
                    .map((state) => state.organization?.id)
                    .distinct(),
              );
              unawaited(cubit.load());
              return cubit;
            },
          ),
          BlocProvider(
            // Listening from the start: a file may be what opened the app.
            lazy: false,
            create: (_) => IncomingCubit(incoming: incoming),
          ),
          BlocProvider(
            lazy: false,
            create: (context) {
              final session = context.read<SessionCubit>();
              final cubit = FeaturesCubit(
                organizationsRepository: organizationsRepository,
                organizationId: session.state.organization?.id,
                organizationChanges: session.stream
                    .map((state) => state.organization?.id)
                    .distinct(),
              );
              unawaited(cubit.load());
              return cubit;
            },
          ),
          BlocProvider(
            // Counted with the app, so the badge is right on the first
            // screen.
            lazy: false,
            create: (context) {
              final session = context.read<SessionCubit>();
              final cubit = UnreadCubit(
                notificationsRepository: notificationsRepository,
                signedIn: session.state.user != null,
                signedInChanges: session.stream
                    .map((state) => state.user != null)
                    .distinct(),
              );
              unawaited(cubit.refresh());
              return cubit;
            },
          ),
          BlocProvider(
            // What waits on the phone is sent as soon as there is a
            // workspace to send it to, not when Settings is first opened.
            lazy: false,
            create: (context) {
              final session = context.read<SessionCubit>();
              final cubit = SyncCubit(
                library: library,
                organizationId: session.state.organization?.id,
                organizationChanges: session.stream
                    .map((state) => state.organization?.id)
                    .distinct(),
              );
              unawaited(cubit.sync());
              return cubit;
            },
          ),
        ],
        child: const AppView(),
      ),
    );
  }
}

class AppView extends StatefulWidget {
  const new({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  late final SessionListenable _session = SessionListenable(
    context.read<SessionCubit>(),
  );
  late final GoRouter _router = createAppRouter(
    preferencesRepository: context.read<PreferencesRepository>(),
    sessionCubit: context.read<SessionCubit>(),
    refresh: _session,
  );

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Whatever happened while the app was away is counted as it returns.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(context.read<UnreadCubit>().refresh());
        unawaited(context.read<SyncCubit>().sync());
        _recover(context.read<SessionCubit>().state.organization?.id);
      },
    );
    // A job the app was closed during is settled as soon as there is a
    // workspace to settle it in: at start, and on moving to another.
    final session = context.read<SessionCubit>();
    _workspaces = session.stream
        .map((state) => state.organization?.id)
        .distinct()
        .listen(_recover);
    _recover(session.state.organization?.id);
  }

  late final StreamSubscription<String?> _workspaces;

  /// Sends the waiting document to the print screen of a printer: the
  /// only one, or the one the person picks. With no printer to print on,
  /// it opens the printers, where one can be added.
  Future<void> _printIncoming() async {
    final incoming = context.read<IncomingCubit>();
    final document = incoming.state;
    final ready =
        context.read<SessionCubit>().state.stage == SessionStage.ready &&
        context.read<PrintersCubit>().state.status == PrintersStatus.ready;
    final navigator = _router.routerDelegate.navigatorKey.currentContext;
    if (document == null || !ready || navigator == null) return;
    incoming.taken();

    if (printersThatPrint(navigator).isEmpty) {
      return _router.go(AppRoutes.printers);
    }
    final printer = await choosePrinter(navigator);
    if (printer != null) {
      _router.go(AppRoutes.printOn(printer.id), extra: document);
    }
  }

  void _recover(String? organizationId) {
    if (organizationId == null) return;
    unawaited(context.read<JobRecovery>().recover(organizationId));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_workspaces.cancel());
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.select<ThemeCubit, AppThemeId>(
      (cubit) => cubit.state,
    );

    // A document another app handed over is printed as soon as there is
    // someone signed in and the printers are known, whichever comes last.
    return MultiBlocListener(
      listeners: [
        BlocListener<IncomingCubit, PickedDocument?>(
          listener: (_, _) => _printIncoming(),
        ),
        BlocListener<SessionCubit, SessionState>(
          listenWhen: (previous, current) => previous.stage != current.stage,
          listener: (_, _) => _printIncoming(),
        ),
        BlocListener<PrintersCubit, PrintersState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (_, _) => _printIncoming(),
        ),
      ],
      child: MaterialApp.router(
        onGenerateTitle: (context) => context.l10n.appName,
        routerConfig: _router,
        theme: AppTheme.of(theme).data(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
