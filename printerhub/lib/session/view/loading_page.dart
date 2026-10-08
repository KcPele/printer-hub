import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/session/cubit/session_cubit.dart';

/// Shown between signing in and the app being ready. If the workspaces
/// cannot be fetched it says why and offers another try.
class LoadingPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<SessionCubit>().state;
    final failed = state.stage == SessionStage.failed;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: failed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppNotice(message: errorMessage(l10n, state.error)),
                      const SizedBox(height: AppSpacing.xl),
                      AppSubmitButton(
                        label: l10n.loadingRetry,
                        onPressed: () => context.read<SessionCubit>().retry(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () => context.read<SessionCubit>().signOut(),
                        child: Text(l10n.settingsSignOut),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The same mark as the launch screen before it, so
                      // the start of the app does not jump.
                      AppLogo(semanticLabel: l10n.appName),
                      const SizedBox(height: AppSpacing.xxl),
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.loadingTitle,
                        style: context.textTheme.titleMedium,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
