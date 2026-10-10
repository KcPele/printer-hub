import 'package:printerhub/copy/cubit/copy_cubit.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/print_words.dart';
import 'package:printerhub/scan/scan_words.dart';

/// The words the app uses for copying: where it has got to, and why it
/// stopped. A copy is a scan and then a print, so most are theirs.
abstract final class CopyWords {
  /// What is happening now.
  static String stage(AppLocalizations l10n, CopyState state) {
    return switch (state.step) {
      CopyStep.printing => PrintWords.stage(l10n, state.progress),
      _ when state.scanned > 0 => l10n.scanStagePages(state.scanned),
      _ => l10n.scanStageScanning,
    };
  }

  /// Why a copy stopped, from its code.
  static String failure(AppLocalizations l10n, String code) {
    if (code.startsWith('scan.') || code.startsWith('escl.')) {
      return ScanWords.failure(l10n, code);
    }
    return switch (code) {
      'copy.nothing_scanned' => l10n.copyNothingScanned,
      'copy.unreadable' => l10n.copyUnreadable,
      'copy.not_printed' => l10n.copyNotPrinted,
      _ => PrintWords.failureOf(l10n, code: code),
    };
  }
}
