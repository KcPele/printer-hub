import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/auth/cubit/submit_cubit.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';

/// The end of a form: why the last attempt failed, if it did, then the
/// button, which shows progress while the request is out.
class SubmitSection<C extends SubmitCubit> extends StatelessWidget {
  const new({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<C>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.failed) ...[
          AppNotice(message: errorMessage(context.l10n, state.error)),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppSubmitButton(
          label: label,
          loading: state.inProgress,
          onPressed: onPressed,
        ),
      ],
    );
  }
}
