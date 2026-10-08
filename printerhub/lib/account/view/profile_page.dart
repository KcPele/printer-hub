import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/account/cubit/account_cubits.dart';
import 'package:printerhub/account/widgets/account_form.dart';
import 'package:printerhub/auth/cubit/submit_cubit.dart';
import 'package:printerhub/auth/widgets/submit_feedback.dart';
import 'package:printerhub/auth/widgets/validators.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/session/session.dart';

/// The name the rest of a workspace sees, and the address the account
/// signs in with.
class ProfilePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          UpdateNameCubit(authRepository: context.read<AuthRepository>()),
      child: const ProfileView(),
    );
  }
}

class ProfileView extends StatefulWidget {
  const new({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: context.read<SessionCubit>().state.user?.name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await context.read<UpdateNameCubit>().submit(name: _name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = context.select<SessionCubit, String>(
      (cubit) => cubit.state.user?.email ?? '',
    );

    return BlocListener<UpdateNameCubit, SubmitState>(
      listenWhen: (previous, current) => current.succeeded,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
        context.pop();
      },
      child: AccountForm(
        title: l10n.profileTitle,
        body: l10n.profileBody,
        formKey: _form,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
            validator: (value) => Validators.name(l10n, value),
            onFieldSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l10n.fieldName,
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The address identifies the account, so it is shown, not edited.
          TextFormField(
            initialValue: email,
            enabled: false,
            decoration: InputDecoration(
              labelText: l10n.fieldEmail,
              prefixIcon: const Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SubmitSection<UpdateNameCubit>(
            label: l10n.profileSave,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
