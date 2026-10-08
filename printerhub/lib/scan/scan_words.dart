import 'package:printerhub/l10n/l10n.dart';
import 'package:printers_repository/printers_repository.dart';

/// The words the app uses for scanning: where the page is, how fine the
/// scan, where it has got to, and why it stopped.
abstract final class ScanWords {
  static String source(AppLocalizations l10n, String source) {
    return source == 'adf' ? l10n.scanSourceFeeder : l10n.scanSourceGlass;
  }

  /// A resolution by what it is good for, with its number.
  static String resolution(AppLocalizations l10n, int dpi) {
    return switch (dpi) {
      <= 150 => l10n.scanResolutionQuick(dpi),
      300 => l10n.scanResolutionStandard(dpi),
      >= 600 => l10n.scanResolutionFine(dpi),
      _ => l10n.scanResolutionDpi(dpi),
    };
  }

  /// What is happening now, while a scan is on its way.
  static String stage(AppLocalizations l10n, ScanProgress? progress) {
    final pages = progress?.pages.length ?? 0;
    return switch (progress?.stage) {
      null || ScanStage.connecting => l10n.scanStageConnecting,
      _ when pages > 0 => l10n.scanStagePages(pages),
      _ => l10n.scanStageScanning,
    };
  }

  /// Why a scan stopped, from its error code.
  static String failure(AppLocalizations l10n, String? code) {
    return switch (code) {
      'scan.unreachable' => l10n.scanFailedUnreachable,
      'scan.not_available' => l10n.scanFailedNotAvailable,
      'scan.no_connection' => l10n.scanFailedNoConnection,
      'scan.source_not_available' => l10n.scanFailedNoFeeder,
      'scan.feeder_empty' => l10n.scanFailedFeederEmpty,
      'scan.feeder_jam' => l10n.scanFailedFeederJam,
      'scan.feeder_open' => l10n.scanFailedFeederOpen,
      'scan.not_ready' => l10n.scanFailedNotReady,
      'scan.busy' => l10n.scanFailedBusy,
      'scan.connection_lost' => l10n.scanFailedConnectionLost,
      'scan.storage' => l10n.scanFailedStorage,
      'scan.keep_interrupted' => l10n.scanKeepInterrupted,
      _ => l10n.scanFailedRefused,
    };
  }
}
