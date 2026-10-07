import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/theme/theme.dart';
import 'package:printerhub/welcome/cubit/welcome_cubit.dart';

/// The first thing a new install shows: what the app does, then a theme to
/// pick.
class WelcomePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WelcomeCubit(
        preferencesRepository: context.read<PreferencesRepository>(),
      ),
      child: const WelcomeView(),
    );
  }
}

class WelcomeView extends StatefulWidget {
  const new({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<WelcomeCubit>();
    final isLastPage = context.select<WelcomeCubit, bool>(
      (cubit) => cubit.state.isLastPage,
    );
    final page = context.select<WelcomeCubit, int>((cubit) => cubit.state.page);

    return BlocListener<WelcomeCubit, WelcomeState>(
      listenWhen: (previous, current) => current.finished,
      listener: (context, state) => context.go(AppRoutes.home),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  // Hidden on the last page but kept in the layout, so nothing
                  // jumps. It cannot be tapped or read aloud while hidden.
                  child: Visibility(
                    visible: !isLastPage,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(
                      onPressed: cubit.finish,
                      child: Text(l10n.welcomeSkip),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: cubit.pageChanged,
                  children: [
                    _Introduction(
                      illustration: AppIllustrations.printer,
                      title: l10n.welcomeFindTitle,
                      body: l10n.welcomeFindBody,
                    ),
                    _Introduction(
                      illustration: AppIllustrations.phonePrint,
                      title: l10n.welcomePrintTitle,
                      body: l10n.welcomePrintBody,
                    ),
                    _Introduction(
                      illustration: AppIllustrations.private,
                      title: l10n.welcomePrivateTitle,
                      body: l10n.welcomePrivateBody,
                    ),
                    _Step(
                      title: l10n.welcomeThemeTitle,
                      body: l10n.welcomeThemeBody,
                      child: const ThemePicker(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  children: [
                    AppPageIndicator(
                      count: WelcomeCubit.pageCount,
                      index: page,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isLastPage
                            ? cubit.finish
                            : () => _pages.nextPage(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                              ),
                        child: Text(
                          isLastPage
                              ? l10n.welcomeGetStarted
                              : l10n.welcomeNext,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Introduction extends StatelessWidget {
  const new({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final AppIllustrations illustration;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _Step(
      title: title,
      body: body,
      child: AppIllustration(illustration, width: 300),
    );
  }
}

/// One welcome screen: something to look at, then a title and a sentence.
class _Step extends StatelessWidget {
  const new({required this.title, required this.body, required this.child});

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: child,
              ),
            ),
          ),
          Text(
            title,
            style: textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            style: textTheme.bodyLarge?.copyWith(
              color: context.colors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
