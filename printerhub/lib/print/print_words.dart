import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/printer_words.dart';
import 'package:printers_repository/printers_repository.dart';

/// The words the app uses for printing: paper, trays, where a print has
/// got to, and why one failed. One place, so they read the same on every
/// screen.
abstract final class PrintWords {
  static const Map<String, String> _paper = {
    'iso_a3': 'A3',
    'iso_a4': 'A4',
    'iso_a5': 'A5',
    'iso_a6': 'A6',
    'iso_b5': 'B5',
    'jis_b5': 'B5 (JIS)',
    'na_letter': 'Letter',
    'na_legal': 'Legal',
    'na_ledger': 'Tabloid',
    'na_executive': 'Executive',
    'na_index-4x6': '4 × 6 in',
    'na_5x7': '5 × 7 in',
  };

  /// A paper size by the name people know it by: `iso_a4_210x297mm` is A4.
  static String paper(String media) {
    final parts = media.split('_');
    if (parts.length < 3) return media;
    final known = _paper['${parts[0]}_${parts[1]}'];
    return known ?? parts.last.replaceAll('x', ' × ');
  }

  /// A tray as it is labelled on the printer: `tray-1` is Tray 1.
  static String tray(AppLocalizations l10n, String id) {
    final numbered = RegExp(r'^tray-(\d+)$').firstMatch(id);
    if (numbered != null) return l10n.printTrayNumber(numbered.group(1)!);
    return switch (id) {
      'by-pass-tray' || 'bypass' || 'manual' => l10n.printTrayBypass,
      'main' => l10n.printTrayMain,
      _ => id,
    };
  }

  static String quality(AppLocalizations l10n, String quality) {
    return switch (quality) {
      'draft' => l10n.printQualityDraft,
      'high' => l10n.printQualityHigh,
      _ => l10n.printQualityNormal,
    };
  }

  static String sides(AppLocalizations l10n, String sides) {
    return switch (sides) {
      'two_sided_long_edge' => l10n.printSidesLong,
      'two_sided_short_edge' => l10n.printSidesShort,
      _ => l10n.printSidesOne,
    };
  }

  /// What is happening now, while a print is on its way.
  static String stage(AppLocalizations l10n, PrintProgress? progress) {
    return switch (progress?.stage) {
      null || PrintStage.connecting => l10n.printStageConnecting,
      PrintStage.preparing => l10n.printStagePreparing,
      PrintStage.sending => l10n.printStageSending,
      PrintStage.attention => l10n.printStageAttention,
      _ => l10n.printStagePrinting,
    };
  }

  /// What the printer has stopped for, in sentences.
  static List<String> attention(AppLocalizations l10n, PrintProgress progress) {
    return [
      for (final reason in progress.reasons)
        PrinterWords.alert(l10n, alertFrom(reason).code),
    ];
  }

  /// Why a print did not finish.
  static String failure(AppLocalizations l10n, PrintProgress? progress) {
    return failureOf(
      l10n,
      code: progress?.errorCode,
      said: progress?.errorMessage,
    );
  }

  /// Why a print did not finish, from the error code its record keeps and
  /// what the printer [said].
  static String failureOf(
    AppLocalizations l10n, {
    required String? code,
    String? said,
  }) {
    return switch (code) {
      'print.unreachable' => l10n.printFailedUnreachable,
      'print.needs_password' => l10n.printFailedNeedsPassword,
      'print.not_available' => l10n.printFailedNotAvailable,
      'print.no_connection' => l10n.printFailedNoConnection,
      'print.format_not_supported' => l10n.printFailedFormat,
      'print.connection_lost' => l10n.printFailedConnectionLost,
      'print.outcome_unknown' => l10n.printFailedUnknown,
      'print.interrupted' => l10n.printFailedInterrupted,
      'scan.interrupted' => l10n.scanFailedInterrupted,
      'ipp.job-aborted' => l10n.printFailedAborted,
      _ when said != null && said.isNotEmpty => l10n.printFailedRefusedWhy(
        said,
      ),
      _ => l10n.printFailedRefused,
    };
  }
}
