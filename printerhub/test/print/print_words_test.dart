import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/print.dart';
import 'package:printers_repository/printers_repository.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('paper is called what people call it', () {
    expect(PrintWords.paper('iso_a4_210x297mm'), 'A4');
    expect(PrintWords.paper('na_letter_8.5x11in'), 'Letter');
    expect(PrintWords.paper('na_ledger_11x17in'), 'Tabloid');
    // Unknown sizes fall back to their measurements.
    expect(PrintWords.paper('om_small-photo_100x150mm'), '100 × 150mm');
    expect(PrintWords.paper('letterhead'), 'letterhead');
  });

  test('trays are called what the printer calls them', () {
    expect(PrintWords.tray(l10n, 'tray-2'), 'Tray 2');
    expect(PrintWords.tray(l10n, 'by-pass-tray'), 'Bypass tray');
    expect(PrintWords.tray(l10n, 'main'), 'Main tray');
    expect(PrintWords.tray(l10n, 'envelope'), 'envelope');
  });

  test('quality and sides have plain names', () {
    expect(PrintWords.quality(l10n, 'draft'), 'Draft');
    expect(PrintWords.quality(l10n, 'normal'), 'Normal');
    expect(PrintWords.quality(l10n, 'high'), 'Best');
    expect(PrintWords.sides(l10n, 'one_sided'), 'One side');
    expect(PrintWords.sides(l10n, 'two_sided_long_edge'), 'Both sides');
    expect(
      PrintWords.sides(l10n, 'two_sided_short_edge'),
      'Both sides, flipped up',
    );
  });

  test('each stage of a print has its sentence', () {
    String stage(PrintStage? stage) =>
        PrintWords.stage(l10n, stage == null ? null : PrintProgress(stage));

    expect(stage(null), 'Reaching the printer…');
    expect(stage(PrintStage.connecting), 'Reaching the printer…');
    expect(stage(PrintStage.preparing), 'Getting the document ready…');
    expect(stage(PrintStage.sending), 'Sending to the printer…');
    expect(stage(PrintStage.printing), 'Printing…');
    expect(stage(PrintStage.attention), 'The printer has stopped');
  });

  test('says what the printer has stopped for', () {
    expect(
      PrintWords.attention(
        l10n,
        const PrintProgress(
          PrintStage.attention,
          reasons: ['media-jam-error', 'door-open-error'],
        ),
      ),
      ['Paper is jammed', 'A door or cover is open'],
    );
  });

  test('each way a print fails has its sentence', () {
    String failure(String? code, [String? message]) => PrintWords.failure(
      l10n,
      PrintProgress(PrintStage.failed, errorCode: code, errorMessage: message),
    );

    expect(failure('print.unreachable'), contains('did not answer'));
    expect(failure('print.needs_password'), contains('user name and password'));
    expect(failure('print.not_available'), contains('not switched on'));
    expect(failure('print.no_connection'), contains('no connection'));
    expect(failure('print.format_not_supported'), contains('cannot take'));
    expect(failure('print.connection_lost'), contains('was lost'));
    expect(failure('print.outcome_unknown'), contains('printed twice'));
    expect(failure('ipp.job-aborted'), contains('gave up'));
    expect(
      failure('ipp.client-error-not-possible', 'Unsupported media'),
      'The printer refused the job: Unsupported media',
    );
    expect(failure('ipp.server-error-busy'), 'The printer refused the job.');
    expect(failure(null, ''), 'The printer refused the job.');
    expect(PrintWords.failure(l10n, null), 'The printer refused the job.');
  });
}
