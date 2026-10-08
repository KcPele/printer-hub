import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/documents/cubit/documents_cubit.dart';
import 'package:printerhub/documents/document_words.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/session/session.dart';

/// The documents the workspace keeps, such as scans: found, opened,
/// renamed, and deleted.
class DocumentsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = DocumentsCubit(
          documentsRepository: context.read<DocumentsRepository>(),
          sharer: context.read<ScanSharer>(),
          organizationId: context.read<SessionCubit>().state.organization!.id,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const DocumentsView(),
    );
  }
}

class DocumentsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DocumentsCubit>();
    final state = context.watch<DocumentsCubit>().state;
    final nothingYet =
        state.status == DocumentsStatus.ready &&
        state.query.isEmpty &&
        state.documents.isEmpty;

    return BlocListener<DocumentsCubit, DocumentsState>(
      listenWhen: (previous, current) =>
          (current.fetchFailed && !previous.fetchFailed) ||
          (current.error != null &&
              current.error != previous.error &&
              current.status == DocumentsStatus.ready),
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.fetchFailed
                ? l10n.documentFetchFailed
                : errorMessage(l10n, state.error),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.documentsTitle)),
        body: SafeArea(
          child: switch (state.status) {
            DocumentsStatus.failed => EmptyState(
              illustration: AppIllustrations.private,
              title: l10n.documentsFailedTitle,
              message: errorMessage(l10n, state.error),
              action: FilledButton(
                onPressed: cubit.load,
                child: Text(l10n.loadingRetry),
              ),
            ),
            _ when nothingYet => EmptyState(
              illustration: AppIllustrations.private,
              title: l10n.documentsEmptyTitle,
              message: l10n.documentsEmptyBody,
            ),
            _ => RefreshIndicator(
              onRefresh: cubit.load,
              child: _Documents(state: state),
            ),
          },
        ),
      ),
    );
  }
}

class _Documents extends StatelessWidget {
  const new({required this.state});

  final DocumentsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DocumentsCubit>();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        TextField(
          textInputAction: TextInputAction.search,
          autocorrect: false,
          onSubmitted: cubit.search,
          decoration: InputDecoration(
            labelText: l10n.documentsSearch,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.status == DocumentsStatus.loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.documents.isEmpty)
          AppCard(
            tone: AppCardTone.muted,
            child: Text(
              l10n.documentsNoMatch,
              style: context.textTheme.bodyLarge,
            ),
          )
        else
          for (final document in state.documents) ...[
            _DocumentCard(
              document: document,
              busy: state.busyId == document.id,
              enabled: state.busyId == null,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        if (state.next != null)
          Align(
            child: TextButton(
              onPressed: state.loadingMore ? null : cubit.more,
              child: Text(l10n.documentsMore),
            ),
          ),
      ],
    );
  }
}

enum _DocumentAction { open, rename, delete }

class _DocumentCard extends StatelessWidget {
  const new({
    required this.document,
    required this.busy,
    required this.enabled,
  });

  final StoredDocument document;

  /// True while this document is being fetched or changed.
  final bool busy;

  /// False while any document is.
  final bool enabled;

  Future<void> _do(BuildContext context, _DocumentAction action) async {
    final cubit = context.read<DocumentsCubit>();
    final l10n = context.l10n;
    switch (action) {
      case _DocumentAction.open:
        await cubit.open(document);
      case _DocumentAction.rename:
        final name = await showDialog<String>(
          context: context,
          builder: (_) => _RenameDialog(name: document.name),
        );
        if (name != null) await cubit.rename(document, name);
      case _DocumentAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.documentDeleteTitle(document.name)),
            content: Text(l10n.documentDeleteBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.documentCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.documentDelete),
              ),
            ],
          ),
        );
        if (confirmed ?? false) await cubit.remove(document);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final colors = context.colors;
    final tag = !document.inCloud
        ? l10n.documentOnPhoneOnly
        : document.awaitsFile
        ? l10n.documentAwaitsFile
        : null;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: enabled && document.canFetch
          ? () => _do(context, _DocumentAction.open)
          : null,
      child: Row(
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(DocumentWords.icon(document), color: colors.emphasis),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.name,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  DocumentWords.detail(context, document),
                  style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                if (tag != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  StatusPill(status: AppStatus.neutral, label: tag),
                ],
              ],
            ),
          ),
          PopupMenuButton<_DocumentAction>(
            enabled: enabled,
            onSelected: (action) => _do(context, action),
            itemBuilder: (_) => [
              if (document.canFetch)
                PopupMenuItem(
                  value: _DocumentAction.open,
                  child: Text(l10n.documentOpen),
                ),
              PopupMenuItem(
                value: _DocumentAction.rename,
                child: Text(l10n.documentRename),
              ),
              PopupMenuItem(
                value: _DocumentAction.delete,
                child: Text(l10n.documentDelete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks what a document should be called.
class _RenameDialog extends StatefulWidget {
  const new({required this.name});

  final String name;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = _name.text.trim();

    return AlertDialog(
      title: Text(l10n.documentRename),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 255,
        decoration: InputDecoration(labelText: l10n.documentNameLabel),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.documentCancel),
        ),
        TextButton(
          onPressed: name.isEmpty || name == widget.name
              ? null
              : () => Navigator.of(context).pop(name),
          child: Text(l10n.documentRenameConfirm),
        ),
      ],
    );
  }
}
