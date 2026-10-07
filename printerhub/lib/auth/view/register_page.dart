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

class RegisterPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RegisterCubit(authRepository: context.read<AuthRepository>()),
      child: const RegisterView(),
    );
  }
}

class RegisterView extends StatefulWidget {
  const new({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await context.read<RegisterCubit>().submit(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Registering signs in, and the router leaves this screen.
    return AuthScaffold(
      formKey: _form,
      illustration: AppIllustrations.createAccount,
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      footer: TextButton(
        onPressed: () => context.go(AppRoutes.signIn),
        child: Text(l10n.registerSignIn),
      ),
      children: [
        TextFormField(
          controller: _name,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          validator: (value) => Validators.name(l10n, value),
          decoration: InputDecoration(
            labelText: l10n.fieldName,
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        formGap,
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
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
          isNew: true,
          validator: (value) => Validators.newPassword(l10n, value),
          onSubmitted: _submit,
        ),
        const SizedBox(height: AppSpacing.xl),
        SubmitSection<RegisterCubit>(
          label: l10n.registerAction,
          onPressed: _submit,
        ),
      ],
    );
  }
}
