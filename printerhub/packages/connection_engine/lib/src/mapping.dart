import 'package:connection_engine/src/device.dart';
import 'package:printer_protocols/printer_protocols.dart';

/// Makers whose names are more than one word, so a model string is split in
/// the right place.
const List<String> _makers = [
  'Hewlett-Packard',
  'Konica Minolta',
  'Fuji Xerox',
  'FUJIFILM Business Innovation',
];

/// Splits "Xerox VersaLink C7130" into the maker and the model.
({String? manufacturer, String? model}) splitMakeAndModel(String? text) {
  final value = text?.trim() ?? '';
  if (value.isEmpty) return (manufacturer: null, model: null);

  for (final maker in _makers) {
    if (value.toLowerCase().startsWith(maker.toLowerCase())) {
      final rest = value.substring(maker.length).trim();
      return (manufacturer: maker, model: rest.isEmpty ? null : rest);
    }
  }
  final space = value.indexOf(' ');
  if (space < 0) return (manufacturer: value, model: null);
  return (
    manufacturer: value.substring(0, space),
    model: value.substring(space + 1).trim(),
  );
}

/// Reads one field of an IEEE 1284 device id, such as `MFG:Xerox;MDL:C7130;`.
String? deviceIdField(String? deviceId, List<String> keys) {
  for (final part in (deviceId ?? '').split(';')) {
    final colon = part.indexOf(':');
    if (colon < 0) continue;
    if (keys.contains(part.substring(0, colon).trim().toUpperCase())) {
      final value = part.substring(colon + 1).trim();
      if (value.isNotEmpty) return value;
    }
  }
  return null;
}

/// What the printer said it can print, in the app's terms.
PrintFeatures printFeaturesFrom(IppPrinterAttributes printer) {
  final sides = printer.sides.map((side) => side.replaceAll('-', '_')).toList();
  return PrintFeatures(
    color: printer.colorSupported,
    duplexModes: sides.isEmpty ? const ['one_sided'] : sides,
    documentFormats: printer.documentFormats,
    mediaSizes: printer.media,
    mediaTypes: printer.mediaTypes,
    trays: [
      for (final source in printer.mediaSources)
        if (source != 'auto') source,
    ],
    maxCopies: printer.maxCopies,
    resolutionsDpi: printer.resolutionsDpi,
    qualities: printer.qualities,
    collation: printer.collationSupported,
    airPrint: printer.supportsAirPrint,
  );
}

const Map<String, String> _scanColorModes = {
  'RGB24': 'color',
  'RGB48': 'color',
  'Grayscale8': 'grayscale',
  'Grayscale16': 'grayscale',
  'BlackAndWhite1': 'monochrome',
};

/// What the scanner said it can scan, in the app's terms.
ScanFeatures scanFeaturesFrom(EsclCapabilities scanner) {
  final inputs = [?scanner.platen, ?scanner.feeder];
  // The glass decides the largest area; the feeder is used when there is
  // no glass.
  final largest = scanner.platen ?? scanner.feeder;

  return ScanFeatures(
    sources: [
      if (scanner.platen != null) 'platen',
      if (scanner.feeder != null) 'adf',
    ],
    feederDuplex: scanner.feederDuplex,
    colorModes: {
      for (final input in inputs)
        for (final mode in input.colorModes) ?_scanColorModes[mode],
    }.toList(),
    documentFormats: {for (final input in inputs) ...input.documentFormats}
        .toList(),
    resolutionsDpi: {
      for (final input in inputs) ...input.resolutionsDpi,
    }.toList()..sort(),
    maxWidthMm: largest?.maxWidthMm,
    maxHeightMm: largest?.maxHeightMm,
  );
}

const List<String> _severities = ['error', 'warning', 'report'];

/// Turns `media-jam-error` into the alert `media-jam` with severity `error`.
DeviceAlert alertFrom(String reason) {
  for (final severity in _severities) {
    if (reason.endsWith('-$severity')) {
      return DeviceAlert(
        code: reason.substring(0, reason.length - severity.length - 1),
        severity: severity == 'report' ? 'info' : severity,
      );
    }
  }
  // A reason without a suffix is a condition that stops printing.
  return DeviceAlert(code: reason, severity: 'error');
}

String _supplyKind(String? type) {
  final value = (type ?? '').toLowerCase();
  if (value.contains('waste')) return 'waste';
  if (value.contains('toner')) return 'toner';
  if (value.contains('ink')) return 'ink';
  if (value.contains('opc') || value.contains('drum')) return 'drum';
  return value.isEmpty ? 'other' : value;
}

/// What the device is doing, from its printer attributes and, when it has a
/// scanner, its scanner status.
DeviceStatus deviceStatusFrom(
  IppPrinterAttributes? printer, {
  EsclStatus? scanner,
}) {
  return DeviceStatus(
    // A device that answers is online, even when it has stopped: what is
    // wrong with it is in the alerts.
    state: printer == null && scanner == null ? 'unknown' : 'online',
    acceptingJobs: printer?.isAcceptingJobs ?? printer != null,
    supplies: [
      for (final marker in printer?.markers ?? const <IppMarker>[])
        Supply(
          name: marker.name,
          kind: _supplyKind(marker.type),
          color: marker.color?.toLowerCase(),
          levelPercent: marker.levelPercent?.clamp(0, 100),
        ),
    ],
    alerts: [
      for (final reason in printer?.stateReasons ?? const <String>[])
        alertFrom(reason),
    ],
    scannerState: switch (scanner?.state) {
      null => 'unknown',
      EsclScannerState.idle => 'idle',
      EsclScannerState.processing => 'busy',
      EsclScannerState.stopped => 'error',
      EsclScannerState.down => 'unavailable',
      EsclScannerState.unknown => 'unknown',
    },
  );
}
