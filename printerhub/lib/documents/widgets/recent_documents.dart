import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/documents/cubit/documents_cubit.dart';
import 'package:printerhub/documents/view/documents_page.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/session/session.dart';

/// The last few documents the person made, each with what can be done
/// with it, and a way to the rest. Shows nothing until there is one, so
/// it can sit on any screen.
class RecentDocuments extends StatelessWidget {
  const new({required this.title, this.limit = 3, super.key});

  final String title;

  /// How many are shown.
  final int limit;

  @override
  Widget build(BuildContext context) {
    final organizationId = context.select<SessionCubit, String?>(
      (cubit) => cubit.state.organization?.id,
    );
    // Signing out leaves a screen without a workspace for a moment.
    if (organizationId == null) return const SizedBox.shrink();

    return BlocProvider(
      // Another workspace has other documents.
      key: ValueKey(organizationId),
      create: (context) {
        final cubit = DocumentsCubit(
          documentsRepository: context.read<DocumentsRepository>(),
          library: context.read<Library>(),
          sharer: context.read<ScanSharer>(),
          organizationId: organizationId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: DocumentsFeedback(
        child: _Recent(title: title, limit: limit),
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const new({required this.title, required this.limit});

  final String title;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<DocumentsCubit>().state;
    if (state.documents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: context.textTheme.titleLarge)),
            TextButton(
              onPressed: () => context.push(AppRoutes.documents),
              child: Text(l10n.documentsSeeAll),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final document in state.documents.take(limit)) ...[
          DocumentCard(document: document, state: state),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
