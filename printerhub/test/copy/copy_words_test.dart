import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/copy/copy.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printers_repository/printers_repository.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('a copy says where it has got to', () {
    expect(
      CopyWords.stage(l10n, const CopyState(step: CopyStep.scanning)),
      'Scanning…',
    );
    expect(
      CopyWords.stage(
        l10n,
        const CopyState(step: CopyStep.scanning, scanned: 2),
      ),
      contains('2 pages'),
    );
    expect(
      CopyWords.stage(
        l10n,
        const CopyState(
          step: CopyStep.printing,
          progress: PrintProgress(PrintStage.sending),
        ),
      ),
      l10n.printStageSending,
    );
  });

  test('a copy says why it stopped in the scanner’s words, the '
      'printer’s, or its own', () {
    expect(
      CopyWords.failure(l10n, 'scan.feeder_empty'),
      l10n.scanFailedFeederEmpty,
    );
    expect(CopyWords.failure(l10n, 'escl.http_500'), l10n.scanFailedRefused);
    expect(
      CopyWords.failure(l10n, 'print.unreachable'),
      l10n.printFailedUnreachable,
    );
    final own = {
      for (final code in [
        'copy.nothing_scanned',
        'copy.unreadable',
        'copy.not_printed',
      ])
        CopyWords.failure(l10n, code),
    };
    expect(own, hasLength(3));
  });
}
