import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printers_repository/printers_repository.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('a source is where the page is put', () {
    expect(ScanWords.source(l10n, 'platen'), 'The glass');
    expect(ScanWords.source(l10n, 'adf'), 'The feeder');
  });

  test('a page is called by its number, or the side of the card it is', () {
    expect(ScanWords.page(l10n, 0), 'Page 1');
    expect(ScanWords.page(l10n, 2), 'Page 3');
    expect(ScanWords.page(l10n, 0, card: true), 'Front');
    expect(ScanWords.page(l10n, 1, card: true), 'Back');
    expect(ScanWords.page(l10n, 2, card: true), 'Front');
  });

  test('a resolution says what it is good for', () {
    expect(ScanWords.resolution(l10n, 75), 'Quick (75 dpi)');
    expect(ScanWords.resolution(l10n, 150), 'Quick (150 dpi)');
    expect(ScanWords.resolution(l10n, 200), '200 dpi');
    expect(ScanWords.resolution(l10n, 300), 'Standard (300 dpi)');
    expect(ScanWords.resolution(l10n, 400), '400 dpi');
    expect(ScanWords.resolution(l10n, 600), 'Fine (600 dpi)');
    expect(ScanWords.resolution(l10n, 1200), 'Fine (1200 dpi)');
  });

  test('a scan on its way says how far it has got', () {
    final page = ScannedPage(file: File('a.jpg'), mimeType: 'image/jpeg');

    expect(ScanWords.stage(l10n, null), 'Reaching the scanner…');
    expect(
      ScanWords.stage(l10n, const ScanProgress(ScanStage.connecting)),
      'Reaching the scanner…',
    );
    expect(
      ScanWords.stage(l10n, const ScanProgress(ScanStage.scanning)),
      'Scanning…',
    );
    expect(
      ScanWords.stage(l10n, ScanProgress(ScanStage.scanning, pages: [page])),
      'Scanning… 1 page so far',
    );
    expect(
      ScanWords.stage(
        l10n,
        ScanProgress(ScanStage.scanning, pages: [page, page]),
      ),
      'Scanning… 2 pages so far',
    );
  });

  test('every way a scan stops has its own sentence', () {
    const codes = [
      'scan.unreachable',
      'scan.not_available',
      'scan.no_connection',
      'scan.source_not_available',
      'scan.feeder_empty',
      'scan.feeder_jam',
      'scan.feeder_open',
      'scan.not_ready',
      'scan.busy',
      'scan.connection_lost',
      'scan.storage',
      'scan.keep_interrupted',
      'scan.camera',
      'escl.http_500',
    ];

    final sentences = {for (final code in codes) ScanWords.failure(l10n, code)};

    expect(sentences, hasLength(codes.length));
    expect(ScanWords.failure(l10n, null), l10n.scanFailedRefused);
    expect(ScanWords.failure(l10n, 'scan.feeder_empty'), contains('empty'));
  });
}
