import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/auth/cubit/auth_cubits.dart';
import 'package:printerhub/auth/widgets/auth_scaffold.dart';
import 'package:printerhub/auth/widgets/password_field.dart';
import 'package:printerhub/auth/widgets/submit_feedback.dart';
import 'package:printerhub/auth/widgets/validators.dart';
import 'package:printerhub/l10n/l10n.dart';

class SignInPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SignInCubit(authRepository: context.read<AuthRepository>()),
      child: const SignInView(),
    );
  }
}

class SignInView extends StatefulWidget {
  const new({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await context.read<SignInCubit>().submit(
      email: _email.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Signing in changes the session, and the router leaves this screen.
    return AuthScaffold(
      formKey: _form,
      illustration: AppIllustrations.signIn,
      title: l10n.signInTitle,
      subtitle: l10n.signInSubtitle,
      footer: TextButton(
        onPressed: () => context.push(AppRoutes.register),
        child: Text(l10n.signInCreate),
      ),
      children: [
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          autocorrect: false,
          validator: (value) => Validators.email(l10n, value),
          decoration: InputDecoration(
            labelText: l10n.fieldEmail,
            prefixIcon: const Icon(Icons.mail_outline),
          ),
        ),
        formGap,
        PasswordField(
          controller: _password,
          label: l10n.fieldPassword,
          validator: (value) => Validators.password(l10n, value),
          onSubmitted: _submit,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => context.push(AppRoutes.forgotPassword),
            child: Text(l10n.signInForgot),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SubmitSection<SignInCubit>(
          label: l10n.signInAction,
          onPressed: _submit,
        ),
      ],
    );
  }
}
