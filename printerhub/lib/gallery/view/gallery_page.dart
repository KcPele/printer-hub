import 'package:app_ui/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/theme/theme.dart';

/// Every shared widget, drawn in the current theme.
///
/// This is the app's first screen until the account screens exist. It is
/// where a new shared widget is checked in all three themes.
class GalleryPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.galleryTitle),
        actions: [
          IconButton(
            tooltip: l10n.galleryChangeTheme,
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => context.push(AppRoutes.theme),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xxxl,
          ),
          children: [
            Text(
              l10n.gallerySubtitle,
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
            _Section(title: l10n.themeTitle, child: const ThemePicker()),
            const SizedBox(height: AppSpacing.xl),
            const _PrinterCard(),
            _Section(
              title: l10n.gallerySectionActivity,
              child: const _Figures(),
            ),
            _Section(
              title: l10n.gallerySectionStatus,
              child: const _Statuses(),
            ),
            _Section(
              title: l10n.gallerySectionSupplies,
              child: const _Supplies(),
            ),
            _Section(
              title: l10n.gallerySectionControls,
              child: const _Controls(),
            ),
            _Section(title: l10n.gallerySectionType, child: const _TypeScale()),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text(title, style: context.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

class _PrinterCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(
                      status: AppStatus.success,
                      label: l10n.galleryStatusOnline,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.galleryPrinterName,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.galleryPrinterLocation,
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppIllustration(
                AppIllustrations.printer,
                width: 124,
                semanticLabel: l10n.galleryPrinterIllustration,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.print_outlined),
                  label: Text(l10n.galleryPrint),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(l10n.galleryScan),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(onPressed: () {}, child: Text(l10n.galleryDetails)),
        ],
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Figure(
              tone: AppCardTone.inverse,
              value: '128',
              label: l10n.galleryStatPrinted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Figure(
              tone: AppCardTone.primary,
              value: '36',
              label: l10n.galleryStatScanned,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Figure(
              tone: AppCardTone.muted,
              value: '2',
              label: l10n.galleryStatQueued,
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const new({required this.tone, required this.value, required this.label});

  final AppCardTone tone;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: tone,
      padding: const EdgeInsets.all(AppSpacing.lg),
      // The card swaps the theme's colours for ones that read on its tone,
      // so the text is styled from the context inside it.
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: context.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Statuses extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        StatusPill(status: AppStatus.success, label: l10n.galleryStatusOnline),
        StatusPill(
          status: AppStatus.warning,
          label: l10n.galleryStatusLowToner,
        ),
        StatusPill(
          status: AppStatus.error,
          label: l10n.galleryStatusPaperJam,
          icon: Icons.error_outline,
        ),
        StatusPill(status: AppStatus.info, label: l10n.galleryStatusPrinting),
        StatusPill(status: AppStatus.neutral, label: l10n.galleryStatusOffline),
      ],
    );
  }
}

class _Supplies extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final supplies = <(TonerColor, String, int?)>[
      (TonerColor.cyan, l10n.gallerySupplyCyan, 72),
      (TonerColor.magenta, l10n.gallerySupplyMagenta, 40),
      (TonerColor.yellow, l10n.gallerySupplyYellow, 8),
      (TonerColor.black, l10n.gallerySupplyBlack, null),
    ];

    return AppCard(
      child: Column(
        children: [
          for (final (toner, label, percent) in supplies) ...[
            if (toner != supplies.first.$1)
              const SizedBox(height: AppSpacing.lg),
            SupplyLevelBar(
              toner: toner,
              label: label,
              valueLabel: percent == null
                  ? l10n.gallerySupplyUnknown
                  : l10n.gallerySupplyPercent(percent),
              level: percent == null ? null : percent / 100,
            ),
          ],
        ],
      ),
    );
  }
}

class _Controls extends StatefulWidget {
  const new();

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  bool _colour = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l10n.galleryFieldLabel,
            hintText: l10n.galleryFieldHint,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: SwitchListTile(
            value: _colour,
            onChanged: (value) => setState(() => _colour = value),
            title: Text(l10n.gallerySwitchTitle),
            subtitle: Text(l10n.gallerySwitchSubtitle),
          ),
        ),
      ],
    );
  }
}

class _TypeScale extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.galleryTypeDisplay, style: textTheme.displaySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.galleryTypeHeadline, style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.galleryTypeBody, style: textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.galleryTypeCaption,
          style: textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
        ),
      ],
    );
  }
}
