import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/session/session.dart';
import 'package:printerhub/theme/theme.dart';

class App extends StatelessWidget {
  const new({
    required this.preferencesRepository,
    required this.authRepository,
    required this.organizationsRepository,
    this.keptOrganizations,
    super.key,
  });

  final PreferencesRepository preferencesRepository;
  final AuthRepository authRepository;
  final OrganizationsRepository organizationsRepository;

  /// The workspace list from the last launch, read before the first frame.
  final List<Organization>? keptOrganizations;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: preferencesRepository),
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: organizationsRepository),
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
