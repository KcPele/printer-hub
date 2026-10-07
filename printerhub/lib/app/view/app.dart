import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/theme/theme.dart';

class App extends StatelessWidget {
  const new({required this.preferencesRepository, super.key});

  final PreferencesRepository preferencesRepository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: preferencesRepository,
      child: BlocProvider(
        create: (_) => ThemeCubit(preferencesRepository: preferencesRepository),
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
  late final GoRouter _router = createAppRouter(
    preferencesRepository: context.read<PreferencesRepository>(),
  );

  @override
  void dispose() {
    _router.dispose();
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
