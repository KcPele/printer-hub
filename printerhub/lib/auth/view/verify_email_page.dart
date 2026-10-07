import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/auth/cubit/auth_cubits.dart';
import 'package:printerhub/auth/cubit/submit_cubit.dart';
import 'package:printerhub/auth/view/reset_password_page.dart';
import 'package:printerhub/auth/widgets/auth_scaffold.dart';
import 'package:printerhub/auth/widgets/submit_feedback.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/session/session.dart';

class VerifyEmailPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = context.read<AuthRepository>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => VerifyEmailCubit(authRepository: authRepository),
        ),
        BlocProvider(
          create: (_) => ResendCodeCubit(authRepository: authRepository),
        ),
      ],
      child: const VerifyEmailView(),
    );
  }
}

class VerifyEmailView extends StatefulWidget {
  const new({super.key});

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await context.read<VerifyEmailCubit>().submit(code: _code.text.trim());
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = context.select<SessionCubit, String>(
      (cubit) => cubit.state.user?.email ?? '',
    );
    final resending = context.select<ResendCodeCubit, bool>(
      (cubit) => cubit.state.inProgress,
    );

    return MultiBlocListener(
      listeners: [
        BlocListener<VerifyEmailCubit, SubmitState>(
          listenWhen: (previous, current) => current.succeeded,
          listener: (context, state) {
            _say(l10n.verifyDone);
            context.pop();
          },
        ),
        BlocListener<ResendCodeCubit, SubmitState>(
          listenWhen: (previous, current) =>
              current.succeeded || current.failed,
          listener: (context, state) => _say(
            state.succeeded
                ? l10n.verifyResent
                : errorMessage(l10n, state.error),
          ),
        ),
      ],
      child: AuthScaffold(
        formKey: _form,
        illustration: AppIllustrations.mail,
        title: l10n.verifyTitle,
        subtitle: l10n.verifySubtitle(email),
        footer: TextButton(
          onPressed: resending
              ? null
              : () => context.read<ResendCodeCubit>().submit(),
          child: Text(l10n.verifyResend),
        ),
        children: [
          CodeField(controller: _code, onSubmitted: _submit),
          const SizedBox(height: AppSpacing.xl),
          SubmitSection<VerifyEmailCubit>(
            label: l10n.verifyAction,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
