import 'package:connection_engine/connection_engine.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:test/test.dart';

IppPrinterAttributes _printer(List<IppAttribute> attributes) {
  return IppPrinterAttributes(IppGroup(IppGroupTag.printer, attributes));
}

IppAttribute _keywords(String name, List<String> values) {
  return IppAttribute.all(name, IppValueTag.keyword, values);
}

const _input = EsclInput(
  maxWidthMm: 216,
  maxHeightMm: 297,
  colorModes: ['RGB24', 'Grayscale8', 'Sepia'],
  documentFormats: ['application/pdf'],
  resolutionsDpi: [300, 600],
);

void main() {
  group('splitMakeAndModel', () {
    test('splits the maker from the model', () {
      expect(splitMakeAndModel('Xerox VersaLink C7130'), (
        manufacturer: 'Xerox',
        model: 'VersaLink C7130',
      ));
      expect(splitMakeAndModel('  HP  LaserJet Pro  '), (
        manufacturer: 'HP',
        model: 'LaserJet Pro',
      ));
    });

    test('knows makers with more than one word', () {
      expect(splitMakeAndModel('Konica Minolta bizhub C250i'), (
        manufacturer: 'Konica Minolta',
        model: 'bizhub C250i',
      ));
      expect(splitMakeAndModel('hewlett-packard'), (
        manufacturer: 'Hewlett-Packard',
        model: null,
      ));
    });

    test('copes with one word and with nothing', () {
      expect(splitMakeAndModel('Brother'), (
        manufacturer: 'Brother',
        model: null,
      ));
      expect(splitMakeAndModel(''), (manufacturer: null, model: null));
      expect(splitMakeAndModel(null), (manufacturer: null, model: null));
    });
  });

  group('deviceIdField', () {
    const id =
        'MFG:Xerox;MDL:VersaLink C7130; sn : ABC123 ;CMD:PDF;EMPTY:;junk';

    test('reads a field by any of its names', () {
      expect(deviceIdField(id, const ['MFG']), 'Xerox');
      expect(deviceIdField(id, const ['MODEL', 'MDL']), 'VersaLink C7130');
      expect(deviceIdField(id, const ['SN']), 'ABC123');
    });

    test('is null for a field that is missing or empty', () {
      expect(deviceIdField(id, const ['DES']), isNull);
      expect(deviceIdField(id, const ['EMPTY']), isNull);
      expect(deviceIdField(null, const ['MFG']), isNull);
    });
  });

  group('printFeaturesFrom', () {
    test('describes what the printer can print', () {
      final features = printFeaturesFrom(
        _printer([
          IppAttribute.single('color-supported', IppValueTag.boolean, true),
          _keywords('sides-supported', ['one-sided', 'two-sided-long-edge']),
          _keywords('media-supported', ['iso_a4_210x297mm']),
          _keywords('media-source-supported', ['auto', 'tray-1', 'tray-2']),
          IppAttribute.single(
            'copies-supported',
            IppValueTag.rangeOfInteger,
            const IppRange(1, 99),
          ),
          IppAttribute.all(
            'document-format-supported',
            IppValueTag.mimeMediaType,
            const ['application/pdf', 'image/urf'],
          ),
        ]),
      );

      expect(features.color, isTrue);
      expect(features.duplexModes, ['one_sided', 'two_sided_long_edge']);
      expect(features.duplex, isTrue);
      expect(features.mediaSizes, ['iso_a4_210x297mm']);
      expect(features.trays, ['tray-1', 'tray-2']);
      expect(features.maxCopies, 99);
      expect(features.airPrint, isTrue);
    });

    test('assumes one side for a printer that does not say', () {
      final features = printFeaturesFrom(_printer([]));

      expect(features.duplexModes, ['one_sided']);
      expect(features.duplex, isFalse);
      expect(features.color, isFalse);
      expect(features, const PrintFeatures());
    });
  });

  group('scanFeaturesFrom', () {
    test('combines the glass and the feeder', () {
      final features = scanFeaturesFrom(
        const EsclCapabilities(
          platen: _input,
          feeder: EsclInput(
            maxWidthMm: 216,
            maxHeightMm: 356,
            colorModes: ['BlackAndWhite1'],
            documentFormats: ['image/jpeg'],
            resolutionsDpi: [150, 300],
          ),
          feederDuplex: true,
        ),
      );

      expect(features.sources, ['platen', 'adf']);
      expect(features.hasGlass, isTrue);
      expect(features.hasFeeder, isTrue);
      expect(features.feederDuplex, isTrue);
      expect(features.colorModes, ['color', 'grayscale', 'monochrome']);
      expect(features.documentFormats, ['application/pdf', 'image/jpeg']);
      expect(features.resolutionsDpi, [150, 300, 600]);
      expect(features.maxHeightMm, 297, reason: 'the glass decides the area');
    });

    test('uses the feeder alone on a sheet-fed scanner', () {
      final features = scanFeaturesFrom(const EsclCapabilities(feeder: _input));

      expect(features.sources, ['adf']);
      expect(features.hasGlass, isFalse);
      expect(features.maxWidthMm, 216);
    });

    test('is empty for a scanner that reports no inputs', () {
      final features = scanFeaturesFrom(const EsclCapabilities());

      expect(features, const ScanFeatures());
      expect(features.maxWidthMm, isNull);
    });
  });

  group('alertFrom', () {
    test('separates the condition from its severity', () {
      expect(
        alertFrom('media-jam-error'),
        const DeviceAlert(code: 'media-jam', severity: 'error'),
      );
      expect(
        alertFrom('toner-low-warning'),
        const DeviceAlert(code: 'toner-low', severity: 'warning'),
      );
      expect(
        alertFrom('spool-area-full-report'),
        const DeviceAlert(code: 'spool-area-full', severity: 'info'),
      );
    });

    test('treats a bare reason as an error', () {
      expect(
        alertFrom('paused'),
        const DeviceAlert(code: 'paused', severity: 'error'),
      );
    });
  });

  group('deviceStatusFrom', () {
    test('reads supplies and alerts from the printer', () {
      final status = deviceStatusFrom(
        _printer([
          IppAttribute.single('printer-state', IppValueTag.enumeration, 5),
          _keywords('printer-state-reasons', [
            'media-jam-error',
            'toner-low-warning',
          ]),
          IppAttribute.single(
            'printer-is-accepting-jobs',
            IppValueTag.boolean,
            false,
          ),
          IppAttribute.all('marker-names', IppValueTag.name, const [
            'Cyan Toner',
            'Black Ink',
            'Drum Unit',
            'Waste Toner Box',
            'Fuser',
            'Staples',
          ]),
          _keywords('marker-types', [
            'toner',
            'ink',
            'opc',
            'waste-toner',
            'fuser',
          ]),
          IppAttribute.all('marker-colors', IppValueTag.name, const [
            'Cyan',
            'black',
          ]),
          IppAttribute.all('marker-levels', IppValueTag.integer, const [
            8,
            0,
            60,
            150,
          ]),
        ]),
        scanner: const EsclStatus(state: EsclScannerState.processing),
      );

      expect(status.state, 'online');
      expect(status.acceptingJobs, isFalse);
      expect(status.hasError, isTrue);
      expect(status.alerts.map((a) => a.code), ['media-jam', 'toner-low']);
      expect(status.scannerState, 'busy');
      expect(status.supplies.map((s) => s.kind), [
        'toner',
        'ink',
        'drum',
        'waste',
        'fuser',
        'other',
      ]);
      expect(status.supplies[0].color, 'cyan');
      expect(status.supplies[0].state, 'low');
      expect(status.supplies[1].state, 'empty');
      expect(status.supplies[2].state, 'ok');
      expect(status.supplies[3].levelPercent, 100, reason: 'clamped');
      expect(status.supplies[4].state, 'unknown');
    });

    test('maps each scanner state', () {
      String scanner(EsclScannerState state) {
        return deviceStatusFrom(
          null,
          scanner: EsclStatus(state: state),
        ).scannerState;
      }

      expect(scanner(EsclScannerState.idle), 'idle');
      expect(scanner(EsclScannerState.stopped), 'error');
      expect(scanner(EsclScannerState.down), 'unavailable');
      expect(scanner(EsclScannerState.unknown), 'unknown');
    });

    test('is online for a scanner with no printer, and accepts no jobs', () {
      final status = deviceStatusFrom(
        null,
        scanner: const EsclStatus(state: EsclScannerState.idle),
      );

      expect(status.state, 'online');
      expect(status.acceptingJobs, isFalse);
      expect(status.hasError, isFalse);
    });

    test('is unknown with nothing to go on', () {
      final status = deviceStatusFrom(null);

      expect(status.state, 'unknown');
      expect(status.scannerState, 'unknown');
    });

    test('assumes a printer that does not say is accepting jobs', () {
      expect(deviceStatusFrom(_printer([])).acceptingJobs, isTrue);
    });
  });

  group('device models', () {
    test('a connection knows what it is for', () {
      final ipp = DeviceConnection(
        type: 'ipp',
        uri: Uri.parse('ipp://h/ipp/print'),
      );
      final ipps = DeviceConnection(
        type: 'ipps',
        uri: Uri.parse('ipps://h/ipp/print'),
      );
      final escl = DeviceConnection(
        type: 'escl',
        uri: Uri.parse('https://h/eSCL'),
      );

      expect(ipp.purposes, ['print', 'status']);
      expect(ipp.isSecure, isFalse);
      expect(ipps.isSecure, isTrue);
      expect(escl.purposes, ['scan']);
      expect(escl.isSecure, isTrue);
      expect(
        ipp,
        DeviceConnection(type: 'ipp', uri: Uri.parse('ipp://h/ipp/print')),
      );
    });

    test('a device shows the best name it has', () {
      const connections = <DeviceConnection>[];

      expect(
        const DeviceDescription(
          host: '10.0.0.5',
          connections: connections,
          manufacturer: 'Xerox',
          model: 'VersaLink C7130',
          name: 'Office',
        ).displayName,
        'Xerox VersaLink C7130',
      );
      expect(
        const DeviceDescription(
          host: '10.0.0.5',
          connections: connections,
          name: 'Office',
        ).displayName,
        'Office',
      );
      expect(
        const DeviceDescription(
          host: '10.0.0.5',
          connections: connections,
        ).displayName,
        '10.0.0.5',
      );
    });

    test('values compare by what they hold', () {
      // Built at run time, so equality is by value and not by identity.
      Supply supply(String name) => Supply(name: name, kind: 'toner');
      DeviceAlert alert(String code) =>
          DeviceAlert(code: code, severity: 'error');
      DeviceStatus status(String state) => DeviceStatus(state: state);
      DeviceDescription device(String host) {
        return DeviceDescription(host: host, connections: const []);
      }

      expect(supply('Cyan'), supply('Cyan'));
      expect(supply('Cyan'), isNot(supply('Black')));
      expect(alert('media-jam'), alert('media-jam'));
      expect(alert('media-jam'), isNot(alert('door-open')));
      expect(status('online'), status('online'));
      expect(status('online'), isNot(status('offline')));
      expect(device('a'), device('a'));
      expect(device('a'), isNot(device('b')));
      expect(DeviceStatus.unreachable.acceptingJobs, isFalse);
      expect(const ScanFeatures(sources: ['adf']), isNot(const ScanFeatures()));
    });
  });
}
