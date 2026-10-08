import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/account/cubit/account_cubits.dart';
import 'package:printerhub/account/widgets/account_form.dart';
import 'package:printerhub/auth/cubit/submit_cubit.dart';
import 'package:printerhub/auth/widgets/password_field.dart';
import 'package:printerhub/auth/widgets/submit_feedback.dart';
import 'package:printerhub/auth/widgets/validators.dart';
import 'package:printerhub/l10n/l10n.dart';

class ChangePasswordPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ChangePasswordCubit(authRepository: context.read<AuthRepository>()),
      child: const ChangePasswordView(),
    );
  }
}

class ChangePasswordView extends StatefulWidget {
  const new({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await context.read<ChangePasswordCubit>().submit(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocListener<ChangePasswordCubit, SubmitState>(
      listenWhen: (previous, current) => current.succeeded,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
        context.pop();
      },
      child: AccountForm(
        title: l10n.passwordTitle,
        body: l10n.passwordBody,
        formKey: _form,
        children: [
          PasswordField(
            controller: _current,
            label: l10n.passwordCurrent,
            validator: (value) => Validators.password(l10n, value),
          ),
          const SizedBox(height: AppSpacing.lg),
          PasswordField(
            controller: _next,
            label: l10n.fieldNewPassword,
            isNew: true,
            validator: (value) => Validators.newPassword(l10n, value),
            onSubmitted: _submit,
          ),
          const SizedBox(height: AppSpacing.xl),
          SubmitSection<ChangePasswordCubit>(
            label: l10n.passwordAction,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
