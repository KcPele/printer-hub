import 'package:app_ui/app_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The frame every account screen shares: a picture, a title and a
/// sentence, then the form on a card, with an optional link underneath.
///
/// It scrolls when the keyboard takes the space.
class AuthScaffold extends StatelessWidget {
  const new({
    required this.illustration,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
    this.formKey,
    super.key,
  });

  final AppIllustrations illustration;
  final String title;
  final String subtitle;

  /// The fields and the button, shown on a card.
  final List<Widget> children;

  /// A way to another screen, under the card.
  final Widget? footer;
  final GlobalKey<FormState>? formKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final canGoBack = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      // Without a way back the bar would be an empty strip.
      appBar: AppBar(toolbarHeight: canGoBack ? null : 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AppIllustration(illustration, height: 168)),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: textTheme.bodyLarge?.copyWith(
                  color: context.colors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: AutofillGroup(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: AppSpacing.md),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The space between two fields of a form.
const formGap = SizedBox(height: AppSpacing.lg);
