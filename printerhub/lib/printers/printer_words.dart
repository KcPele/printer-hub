import 'package:api_client/api_client.dart';
import 'package:app_ui/app_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printers_repository/printers_repository.dart';

/// How a printer's state is shown: a colour and a word.
typedef PrinterStanding = ({AppStatus status, String label});

/// The words the app uses for what printers report.
///
/// One place, so a paper jam is called the same thing on every screen.
abstract final class PrinterWords {
  /// The standing of a printer from what the device said when it was last
  /// asked ([live]), or else from the backend's record of it.
  static PrinterStanding standing(
    AppLocalizations l10n,
    PrinterRead printer, {
    DeviceStatus? live,
  }) {
    final state = live?.state ?? printer.status.json ?? 'unknown';
    final severities = live != null
        ? live.alerts.map((alert) => alert.severity)
        : printer.statusDetail.alerts.map((alert) => alert.severity.json);

    return switch (state) {
      'online' when severities.contains('error') => (
        status: AppStatus.error,
        label: l10n.printerStatusAttention,
      ),
      'online' when severities.contains('warning') => (
        status: AppStatus.warning,
        label: l10n.printerStatusWarning,
      ),
      'online' => (status: AppStatus.success, label: l10n.printerStatusReady),
      'offline' || 'sleeping' => (
        status: AppStatus.neutral,
        label: l10n.printerStatusOffline,
      ),
      'unreachable' => (
        status: AppStatus.neutral,
        label: l10n.printerStatusUnreachable,
      ),
      _ => (status: AppStatus.neutral, label: l10n.printerStatusUnknown),
    };
  }

  /// How a saved connection did when it was last tried: a colour and a
  /// few words.
  static PrinterStanding health(
    AppLocalizations l10n,
    ConnectionRead connection,
  ) {
    return switch (connection.health.json) {
      'connected' => (status: AppStatus.success, label: l10n.healthConnected),
      'degraded' => (status: AppStatus.warning, label: l10n.healthDegraded),
      'unavailable' => (status: AppStatus.error, label: l10n.healthUnavailable),
      'auth_required' => (
        status: AppStatus.warning,
        label: l10n.healthAuthRequired,
      ),
      'config_required' => (
        status: AppStatus.warning,
        label: l10n.healthConfigRequired,
      ),
      _ => (status: AppStatus.neutral, label: l10n.healthUnknown),
    };
  }

  /// What a connection is for and where it goes: "Printing · 192.168.1.40".
  static String connection(AppLocalizations l10n, ConnectionRead connection) {
    final purpose = connection.type == ConnectionType.escl
        ? l10n.connectionScanning
        : l10n.connectionPrinting;
    return '$purpose · ${connection.configuration.host ?? ''}';
  }

  /// A sentence for an alert the device raised, by its code.
  static String alert(AppLocalizations l10n, String code) {
    return switch (code) {
      'media-jam' => l10n.alertPaperJam,
      'door-open' || 'cover-open' || 'interlock-open' => l10n.alertDoorOpen,
      'toner-low' || 'marker-supply-low' => l10n.alertTonerLow,
      'toner-empty' || 'marker-supply-empty' => l10n.alertTonerEmpty,
      'media-low' => l10n.alertPaperLow,
      'media-empty' || 'media-needed' => l10n.alertPaperEmpty,
      _ => l10n.alertOther(code.replaceAll('-', ' ')),
    };
  }

  /// What a device can do, in plain sentences, from a probe.
  static List<String> features(
    AppLocalizations l10n,
    DeviceDescription device,
  ) {
    return _features(
      l10n,
      prints: device.print != null,
      color: device.print?.color ?? false,
      duplex: device.print?.duplex ?? false,
      glass: device.scan?.hasGlass ?? false,
      feeder: device.scan?.hasFeeder ?? false,
    );
  }

  /// What a saved printer can do, in plain sentences.
  static List<String> abilities(AppLocalizations l10n, PrinterRead printer) {
    final capabilities = printer.capabilities;
    if (capabilities == null) return const [];
    final sources = [
      for (final source in capabilities.scan.sources) source.json,
    ];
    return _features(
      l10n,
      prints: capabilities.print.supported,
      color: capabilities.print.color,
      duplex: capabilities.print.duplexModes.any(
        (mode) => mode != DuplexMode.oneSided,
      ),
      glass: capabilities.scan.supported && sources.contains('platen'),
      feeder: capabilities.scan.supported && sources.contains('adf'),
    );
  }

  /// What the printers of a family usually do, in plain sentences.
  static List<String> family(AppLocalizations l10n, PrinterFamily family) {
    return _features(
      l10n,
      prints: true,
      color: family.color,
      duplex: family.duplex,
      glass: family.scans,
      feeder: family.feeder,
    );
  }

  static List<String> _features(
    AppLocalizations l10n, {
    required bool prints,
    required bool color,
    required bool duplex,
    required bool glass,
    required bool feeder,
  }) {
    return [
      if (!prints)
        l10n.featureNoPrint
      else if (color)
        l10n.featureColor
      else
        l10n.featureMono,
      if (prints && duplex) l10n.featureDuplex,
      if (glass && feeder)
        l10n.featureScanBoth
      else if (glass)
        l10n.featureScanGlass
      else if (feeder)
        l10n.featureScanFeeder,
      if (prints && (glass || feeder)) l10n.featureCopy,
    ];
  }

  /// The toner colour for a supply's reported colour, or null when it is
  /// not one of the four.
  static TonerColor? toner(String? color) => switch (color?.toLowerCase()) {
    'cyan' => TonerColor.cyan,
    'magenta' => TonerColor.magenta,
    'yellow' => TonerColor.yellow,
    'black' => TonerColor.black,
    _ => null,
  };
}
