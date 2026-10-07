import 'package:app_ui/app_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';

/// The list of printers. Until a printer is added it explains what will
/// appear here.
class PrintersPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navPrinters)),
      body: EmptyState(
        illustration: AppIllustrations.printer,
        title: l10n.printersEmptyTitle,
        message: l10n.printersEmptyBody,
      ),
    );
  }
}
