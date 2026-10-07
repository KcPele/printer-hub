import 'dart:ui';

import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printers_repository/printers_repository.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  PrinterRead printer({
    String status = 'online',
    List<Map<String, Object?>> alerts = const [],
    bool scans = true,
  }) {
    return PrinterRead.fromJson(
      printerBody(status: status, alerts: alerts, scans: scans).cast(),
    );
  }

  DeviceStatus live(String state, [List<String> severities = const []]) {
    return DeviceStatus(
      state: state,
      alerts: [for (final s in severities) DeviceAlert(code: 'x', severity: s)],
    );
  }

  group('PrinterWords.standing', () {
    test('goes by what the device said when it was asked', () {
      final record = printer(status: 'unreachable');

      expect(PrinterWords.standing(l10n, record, live: live('online')), (
        status: AppStatus.success,
        label: 'Ready',
      ));
      expect(
        PrinterWords.standing(l10n, record, live: live('online', ['warning'])),
        (status: AppStatus.warning, label: 'Check soon'),
      );
      expect(
        PrinterWords.standing(
          l10n,
          record,
          live: live('online', ['warning', 'error']),
        ),
        (status: AppStatus.error, label: 'Needs attention'),
      );
      expect(PrinterWords.standing(l10n, record, live: live('offline')), (
        status: AppStatus.neutral,
        label: 'Offline',
      ));
      expect(PrinterWords.standing(l10n, record, live: live('unreachable')), (
        status: AppStatus.neutral,
        label: 'Not reachable',
      ));
    });

    test('falls back to the backend record of the printer', () {
      Map<String, Object?> alert(String severity) => {
        'code': 'toner-low',
        'severity': severity,
        'message': null,
      };

      expect(PrinterWords.standing(l10n, printer()).label, 'Ready');
      expect(
        PrinterWords.standing(l10n, printer(alerts: [alert('error')])).status,
        AppStatus.error,
      );
      expect(
        PrinterWords.standing(l10n, printer(alerts: [alert('warning')])).status,
        AppStatus.warning,
      );
      expect(
        PrinterWords.standing(l10n, printer(status: 'sleeping')).label,
        'Offline',
      );
      expect(
        PrinterWords.standing(l10n, printer(status: 'unknown')).label,
        'Not checked yet',
      );
      expect(
        PrinterWords.standing(l10n, printer(status: 'from-the-future')).label,
        'Not checked yet',
      );
    });
  });

  test('PrinterWords.alert has a sentence for each condition', () {
    expect(PrinterWords.alert(l10n, 'media-jam'), 'Paper is jammed');
    expect(PrinterWords.alert(l10n, 'door-open'), 'A door or cover is open');
    expect(PrinterWords.alert(l10n, 'cover-open'), 'A door or cover is open');
    expect(PrinterWords.alert(l10n, 'toner-low'), 'Toner is low');
    expect(PrinterWords.alert(l10n, 'marker-supply-empty'), 'Toner is empty');
    expect(PrinterWords.alert(l10n, 'media-low'), 'Paper is low');
    expect(PrinterWords.alert(l10n, 'media-needed'), 'Out of paper');
    expect(
      PrinterWords.alert(l10n, 'fuser-over-temp'),
      'The printer reports: fuser over temp',
    );
  });

  group('PrinterWords.features', () {
    DeviceDescription device({PrintFeatures? print, ScanFeatures? scan}) {
      return DeviceDescription(
        host: 'h',
        connections: const [],
        print: print,
        scan: scan,
      );
    }

    test('describes a colour device that prints, scans, and copies', () {
      expect(
        PrinterWords.features(
          l10n,
          device(
            print: const PrintFeatures(
              color: true,
              duplexModes: ['one_sided', 'two_sided_long_edge'],
            ),
            scan: const ScanFeatures(sources: ['platen', 'adf']),
          ),
        ),
        [
          'Prints in colour',
          'Prints on both sides',
          'Scans from the glass and the feeder',
          'Copies',
        ],
      );
    });

    test('describes a plain black and white printer', () {
      expect(
        PrinterWords.features(l10n, device(print: const PrintFeatures())),
        ['Prints in black and white'],
      );
    });

    test('describes a scanner that does not print', () {
      expect(
        PrinterWords.features(
          l10n,
          device(scan: const ScanFeatures(sources: ['platen'])),
        ),
        ['Does not print over the network', 'Scans from the glass'],
      );
      expect(
        PrinterWords.features(
          l10n,
          device(scan: const ScanFeatures(sources: ['adf'])),
        ),
        ['Does not print over the network', 'Scans from the feeder'],
      );
    });
  });

  group('PrinterWords.abilities', () {
    test('describes a saved printer from its capabilities', () {
      expect(PrinterWords.abilities(l10n, printer()), [
        'Prints in colour',
        'Prints on both sides',
        'Scans from the glass and the feeder',
        'Copies',
      ]);
      expect(PrinterWords.abilities(l10n, printer(scans: false)), [
        'Prints in colour',
        'Prints on both sides',
      ]);
    });

    test('says nothing for a printer whose capabilities are not known', () {
      final unknown = PrinterRead.fromJson(
        {...printerBody(), 'capabilities': null}.cast(),
      );

      expect(PrinterWords.abilities(l10n, unknown), isEmpty);
    });
  });

  test('PrinterWords.toner recognises the four toner colours', () {
    expect(PrinterWords.toner('cyan'), TonerColor.cyan);
    expect(PrinterWords.toner('Magenta'), TonerColor.magenta);
    expect(PrinterWords.toner('yellow'), TonerColor.yellow);
    expect(PrinterWords.toner('BLACK'), TonerColor.black);
    expect(PrinterWords.toner('#FF8800'), isNull);
    expect(PrinterWords.toner(null), isNull);
  });
}
