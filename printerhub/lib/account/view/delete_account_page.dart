import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/account/cubit/account_cubits.dart';
import 'package:printerhub/account/widgets/account_form.dart';
import 'package:printerhub/auth/widgets/password_field.dart';
import 'package:printerhub/auth/widgets/submit_feedback.dart';
import 'package:printerhub/auth/widgets/validators.dart';
import 'package:printerhub/l10n/l10n.dart';

/// Deletes the account for good. It asks for the password, so a phone left
/// unlocked is not enough to do it.
class DeleteAccountPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DeleteAccountCubit(authRepository: context.read<AuthRepository>()),
      child: const DeleteAccountView(),
    );
  }
}

class DeleteAccountView extends StatefulWidget {
  const new({super.key});

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await context.read<DeleteAccountCubit>().submit(password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Deleting ends the session, and the router leaves this screen.
    return AccountForm(
      title: l10n.deleteAccountTitle,
      body: l10n.deleteAccountBody,
      formKey: _form,
      children: [
        AppNotice(
          status: AppStatus.warning,
          message: l10n.deleteAccountWarning,
        ),
        const SizedBox(height: AppSpacing.lg),
        PasswordField(
          controller: _password,
          label: l10n.fieldPassword,
          validator: (value) => Validators.password(l10n, value),
          onSubmitted: _submit,
        ),
        const SizedBox(height: AppSpacing.xl),
        SubmitSection<DeleteAccountCubit>(
          label: l10n.deleteAccountAction,
          onPressed: _submit,
        ),
      ],
    );
  }
}
