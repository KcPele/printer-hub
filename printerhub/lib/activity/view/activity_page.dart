import 'package:app_ui/app_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';

/// Job history. Until something is printed or scanned it explains what will
/// appear here.
class ActivityPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navActivity)),
      body: EmptyState(
        illustration: AppIllustrations.phonePrint,
        title: l10n.activityEmptyTitle,
        message: l10n.activityEmptyBody,
      ),
    );
  }
}
