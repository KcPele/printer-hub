import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/auth/auth.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/session/cubit/create_workspace_cubit.dart';
import 'package:printerhub/session/cubit/session_cubit.dart';

/// Shown to a person who has no workspace yet, right after they register.
class CreateWorkspacePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CreateWorkspaceCubit(sessionCubit: context.read<SessionCubit>()),
      child: const CreateWorkspaceView(),
    );
  }
}

class CreateWorkspaceView extends StatefulWidget {
  const new({super.key});

  @override
  State<CreateWorkspaceView> createState() => _CreateWorkspaceViewState();
}

class _CreateWorkspaceViewState extends State<CreateWorkspaceView> {
  final _form = GlobalKey<FormState>();
  TextEditingController? _name;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Suggest a name, so most people only press Continue.
    if (_name == null) {
      final user = context.read<SessionCubit>().state.user;
      final firstName = (user?.name ?? '').trim().split(' ').first;
      _name = TextEditingController(
        text: firstName.isEmpty
            ? ''
            : context.l10n.workspaceDefaultName(firstName),
      );
    }
  }

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await context.read<CreateWorkspaceCubit>().submit(name: _name!.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Creating the workspace changes the session, and the router leaves.
    return AuthScaffold(
      formKey: _form,
      illustration: AppIllustrations.printer,
      title: l10n.workspaceTitle,
      subtitle: l10n.workspaceSubtitle,
      footer: TextButton(
        onPressed: () => context.read<SessionCubit>().signOut(),
        child: Text(l10n.settingsSignOut),
      ),
      children: [
        TextFormField(
          controller: _name,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          validator: (value) => Validators.workspace(l10n, value),
          onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.workspaceField,
            prefixIcon: const Icon(Icons.apartment_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SubmitSection<CreateWorkspaceCubit>(
          label: l10n.workspaceAction,
          onPressed: _submit,
        ),
      ],
    );
  }
}
