import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// One picture of the shared widgets per theme, light and dark. Text is
/// drawn as blocks by the test font, so these check colour, shape, depth,
/// and layout.
///
/// Update with: flutter test --update-goldens --tags golden
void main() {
  for (final (theme, brightness) in [
    for (final theme in AppTheme.all)
      for (final brightness in Brightness.values) (theme, brightness),
  ]) {
    // The light pictures keep the names they always had.
    final name = brightness == Brightness.light
        ? theme.id.name
        : '${theme.id.name}_dark';
    testWidgets(
      'shared widgets in ${theme.id.name}, ${brightness.name}',
      tags: 'golden',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 1180));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.data(brightness),
            home: const _Showcase(),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(_Showcase),
          matchesGoldenFile('goldens/shared_widgets_$name.png'),
        );
      },
    );
  }
}

class _Showcase extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.lg);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Printers', style: context.textTheme.headlineLarge),
            gap,
            AppCard(
              child: Row(
                children: [
                  const AppIllustration(AppIllustrations.printer, width: 96),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Office', style: context.textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.sm),
                        const StatusPill(
                          status: AppStatus.success,
                          label: 'Online',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            gap,
            const Row(
              children: [
                Expanded(
                  child: AppCard(tone: AppCardTone.inverse, child: _CardText()),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppCard(tone: AppCardTone.primary, child: _CardText()),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppCard(tone: AppCardTone.muted, child: _CardText()),
                ),
              ],
            ),
            gap,
            const Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                StatusPill(status: AppStatus.warning, label: 'Low toner'),
                StatusPill(
                  status: AppStatus.error,
                  label: 'Paper jam',
                  icon: Icons.error_outline,
                ),
                StatusPill(status: AppStatus.info, label: 'Printing'),
                StatusPill(status: AppStatus.neutral, label: 'Offline'),
              ],
            ),
            gap,
            const AppCard(
              child: Column(
                children: [
                  SupplyLevelBar(
                    toner: TonerColor.cyan,
                    label: 'Cyan',
                    valueLabel: '72%',
                    level: 0.72,
                  ),
                  SizedBox(height: AppSpacing.md),
                  SupplyLevelBar(
                    toner: TonerColor.magenta,
                    label: 'Magenta',
                    valueLabel: '40%',
                    level: 0.4,
                  ),
                  SizedBox(height: AppSpacing.md),
                  SupplyLevelBar(
                    toner: TonerColor.yellow,
                    label: 'Yellow',
                    valueLabel: '8%',
                    level: 0.08,
                  ),
                  SizedBox(height: AppSpacing.md),
                  SupplyLevelBar(
                    toner: TonerColor.black,
                    label: 'Black',
                    valueLabel: 'Unknown',
                    level: null,
                  ),
                ],
              ),
            ),
            gap,
            const TextField(decoration: InputDecoration(hintText: 'Address')),
            gap,
            FilledButton(onPressed: () {}, child: const Text('Add printer')),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: () {}, child: const Text('Browse')),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: () {}, child: const Text('Not now')),
            gap,
            Row(
              children: [
                for (final theme in AppTheme.all) ...[
                  Expanded(
                    child: AppThemePreview(
                      theme: theme,
                      label: theme.id.name,
                      selected: theme.id == AppThemeId.indigo,
                    ),
                  ),
                  if (theme != AppTheme.all.last)
                    const SizedBox(width: AppSpacing.md),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardText extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('12', style: context.textTheme.headlineMedium),
        Text(
          'Jobs',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.textMuted,
          ),
        ),
      ],
    );
  }
}
