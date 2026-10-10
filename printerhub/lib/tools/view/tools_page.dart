import 'package:app_ui/app_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/tools/tool_list.dart';
import 'package:printerhub/tools/widgets/tool_tiles.dart';

/// Every tool the app has, in one place. Home shows the first few.
class ToolsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              l10n.toolsLead,
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ToolGrid(tiles: toolTiles(context)),
          ],
        ),
      ),
    );
  }
}
