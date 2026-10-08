import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/catalogue/cubit/catalogue_cubit.dart';
import 'package:printerhub/catalogue/widgets/family_sheet.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printers_repository/printers_repository.dart';

/// The printers PrinterHub knows about, by family: what each usually does
/// and how to get one ready. Any printer can be added, listed or not.
class CataloguePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = CatalogueCubit(
          printersRepository: context.read<PrintersRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const CatalogueView(),
    );
  }
}

class CatalogueView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CatalogueCubit>();
    final state = context.watch<CatalogueCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalogueTitle)),
      body: SafeArea(
        child: switch (state.status) {
          CatalogueStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          CatalogueStatus.failed => EmptyState(
            illustration: AppIllustrations.printer,
            title: l10n.catalogueFailedTitle,
            message: errorMessage(l10n, state.error),
            action: FilledButton(
              onPressed: cubit.load,
              child: Text(l10n.loadingRetry),
            ),
          ),
          CatalogueStatus.ready => _Families(state: state),
        },
      ),
    );
  }
}

class _Families extends StatelessWidget {
  const new({required this.state});

  final CatalogueState state;

  void _add(BuildContext context) => context.go(AppRoutes.addPrinter);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CatalogueCubit>();
    final visible = state.visible;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        TextField(
          onChanged: cubit.search,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.catalogueSearch,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final (filter, label) in [
              (CatalogueFilter.all, l10n.catalogueAll),
              (CatalogueFilter.home, l10n.catalogueHome),
              (CatalogueFilter.office, l10n.catalogueOffice),
            ])
              ChoiceChip(
                label: Text(label),
                selected: state.filter == filter,
                onSelected: (_) => cubit.show(filter),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (visible.isEmpty)
          AppCard(
            tone: AppCardTone.muted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.catalogueNoMatch, style: context.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => _add(context),
                    child: Text(l10n.catalogueAddAnyway),
                  ),
                ),
              ],
            ),
          )
        else
          for (final family in visible) ...[
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  family.isHome
                      ? Icons.home_outlined
                      : Icons.apartment_outlined,
                ),
                title: Text(family.title),
                subtitle: family.summary == null ? null : Text(family.summary!),
                trailing: Icon(
                  Icons.chevron_right,
                  color: context.colors.textMuted,
                ),
                onTap: () => showFamilySheet(
                  context,
                  family,
                  onAdd: () => _add(context),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}
