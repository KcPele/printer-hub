import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/auth/cubit/auth_cubits.dart';
import 'package:printerhub/auth/cubit/submit_cubit.dart';
import 'package:printerhub/auth/widgets/auth_scaffold.dart';
import 'package:printerhub/auth/widgets/password_field.dart';
import 'package:printerhub/auth/widgets/submit_feedback.dart';
import 'package:printerhub/auth/widgets/validators.dart';
import 'package:printerhub/l10n/l10n.dart';

class ResetPasswordPage extends StatelessWidget {
  const new({required this.email, super.key});

  /// The address the code was sent to.
  final String email;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ResetPasswordCubit(authRepository: context.read<AuthRepository>()),
      child: ResetPasswordView(email: email),
    );
  }
}

class ResetPasswordView extends StatefulWidget {
  const new({required this.email, super.key});

  final String email;

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await context.read<ResetPasswordCubit>().submit(
      email: widget.email,
      code: _code.text.trim(),
      newPassword: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocListener<ResetPasswordCubit, SubmitState>(
      listenWhen: (previous, current) => current.succeeded,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.resetDone)));
        context.go(AppRoutes.signIn);
      },
      child: AuthScaffold(
        formKey: _form,
        illustration: AppIllustrations.private,
        title: l10n.resetTitle,
        subtitle: l10n.resetSubtitle(widget.email),
        children: [
          CodeField(controller: _code),
          formGap,
          PasswordField(
            controller: _password,
            label: l10n.fieldNewPassword,
            isNew: true,
            validator: (value) => Validators.newPassword(l10n, value),
            onSubmitted: _submit,
          ),
          const SizedBox(height: AppSpacing.xl),
          SubmitSection<ResetPasswordCubit>(
            label: l10n.resetAction,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// The field for a 6-digit code from an email.
class CodeField extends StatelessWidget {
  const new({required this.controller, this.onSubmitted, super.key});

  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      validator: (value) => Validators.code(l10n, value),
      onFieldSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: l10n.fieldCode,
        prefixIcon: const Icon(Icons.pin_outlined),
      ),
    );
  }
}
