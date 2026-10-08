import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/theme/theme.dart';
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
    required this.finders,
    required this.documents,
    required this.scanSharer,
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

  /// The ways this phone can find a printer.
  final PrinterFinders finders;

  /// The ways this phone gets at documents to print.
  final PrintDocuments documents;

  /// The way this phone hands a finished scan on.
  final ScanSharer scanSharer;

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
        RepositoryProvider.value(value: documentsRepository),
        RepositoryProvider.value(value: finders),
        RepositoryProvider.value(value: documents),
        RepositoryProvider.value(value: scanSharer),
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

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.select<ThemeCubit, AppThemeId>(
      (cubit) => cubit.state,
    );

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      routerConfig: _router,
      theme: AppTheme.of(theme).data(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
