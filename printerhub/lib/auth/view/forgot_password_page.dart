import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/auth/cubit/auth_cubits.dart';
import 'package:printerhub/auth/cubit/submit_cubit.dart';
import 'package:printerhub/auth/widgets/auth_scaffold.dart';
import 'package:printerhub/auth/widgets/submit_feedback.dart';
import 'package:printerhub/auth/widgets/validators.dart';
import 'package:printerhub/l10n/l10n.dart';

class ForgotPasswordPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ForgotPasswordCubit(authRepository: context.read<AuthRepository>()),
      child: const ForgotPasswordView(),
    );
  }
}

class ForgotPasswordView extends StatefulWidget {
  const new({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await context.read<ForgotPasswordCubit>().submit(email: _email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocListener<ForgotPasswordCubit, SubmitState>(
      listenWhen: (previous, current) => current.succeeded,
      listener: (context, state) =>
          context.push(AppRoutes.resetPassword, extra: _email.text.trim()),
      child: AuthScaffold(
        formKey: _form,
        illustration: AppIllustrations.mail,
        title: l10n.forgotTitle,
        subtitle: l10n.forgotSubtitle,
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            validator: (value) => Validators.email(l10n, value),
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.fieldEmail,
              prefixIcon: const Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SubmitSection<ForgotPasswordCubit>(
            label: l10n.forgotAction,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
