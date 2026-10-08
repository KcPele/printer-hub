import 'package:api_client/api_client.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printers_repository/printers_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows a code another member can scan to open [printer] on their phone.
Future<void> showPairingCode(BuildContext context, PrinterRead printer) {
  final repository = context.read<PrintersRepository>();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PairingCodeSheet(
      printerName: printer.friendlyName,
      code: repository.createPairingCode(
        organizationId: printer.organizationId,
        printerId: printer.id,
      ),
    ),
  );
}

class PairingCodeSheet extends StatelessWidget {
  const new({required this.printerName, required this.code, super.key});

  final String printerName;

  /// The link to show, once the backend has made it.
  final Future<({String link, DateTime expiresAt})> code;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.printerShareTitle,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.printerShareBody(printerName),
              style: textTheme.bodyMedium?.copyWith(
                color: context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox.square(
              dimension: 240,
              child: FutureBuilder(
                future: code,
                builder: (context, snapshot) {
                  final made = snapshot.data;
                  if (made != null) {
                    // Black on white whatever the theme: a camera has to
                    // read it.
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: context.shapes.chipRadius,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: QrImageView(
                          data: made.link,
                          semanticsLabel: l10n.printerShareSemantics(
                            printerName,
                          ),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: AppNotice(
                        message: errorMessage(
                          l10n,
                          ApiException.from(snapshot.error!),
                        ),
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
