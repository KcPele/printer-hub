import 'package:app_ui/app_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The shape of an account screen with one form: a sentence saying what it
/// is for, then the fields and the button on a card.
class AccountForm extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    required this.formKey,
    required this.children,
    super.key,
  });

  final String title;
  final String body;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                body,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
