import 'package:printer_protocols/printer_protocols.dart';
import 'package:test/test.dart';

IppAttribute _keywords(String name, List<String> values) {
  return IppAttribute.all(name, IppValueTag.keyword, values);
}

void main() {
  group('IppPrinterAttributes', () {
    final printer = IppPrinterAttributes(
      IppGroup(IppGroupTag.printer, [
        IppAttribute.single('printer-name', IppValueTag.name, 'Office'),
        IppAttribute.single('printer-info', IppValueTag.text, 'Second floor'),
        IppAttribute.single('printer-location', IppValueTag.text, 'Kitchen'),
        IppAttribute.single(
          'printer-make-and-model',
          IppValueTag.text,
          'Xerox VersaLink C7130',
        ),
        IppAttribute.single(
          'printer-device-id',
          IppValueTag.text,
          'MFG:Xerox;',
        ),
        IppAttribute.single(
          'printer-uuid',
          IppValueTag.uri,
          'urn:uuid:abc-123',
        ),
        IppAttribute.single('printer-more-info', IppValueTag.uri, 'http://p/'),
        IppAttribute.single('printer-state', IppValueTag.enumeration, 4),
        _keywords('printer-state-reasons', ['none', 'toner-low-warning']),
        IppAttribute.single(
          'printer-is-accepting-jobs',
          IppValueTag.boolean,
          true,
        ),
        IppAttribute.single('queued-job-count', IppValueTag.integer, 2),
        IppAttribute.all(
          'document-format-supported',
          IppValueTag.mimeMediaType,
          const ['application/pdf', 'image/urf'],
        ),
        IppAttribute.single(
          'document-format-default',
          IppValueTag.mimeMediaType,
          'application/pdf',
        ),
        IppAttribute.single('color-supported', IppValueTag.boolean, true),
        _keywords('print-color-mode-supported', [
          'auto',
          'color',
          'monochrome',
        ]),
        _keywords('sides-supported', ['one-sided', 'two-sided-long-edge']),
        _keywords('media-supported', [
          'iso_a4_210x297mm',
          'na_letter_8.5x11in',
        ]),
        IppAttribute.single(
          'media-default',
          IppValueTag.keyword,
          'iso_a4_210x297mm',
        ),
        _keywords('media-type-supported', ['stationery']),
        _keywords('media-source-supported', ['auto', 'tray-1']),
        IppAttribute.single(
          'copies-supported',
          IppValueTag.rangeOfInteger,
          const IppRange(1, 999),
        ),
        IppAttribute.all(
          'printer-resolution-supported',
          IppValueTag.resolution,
          const [
            IppResolution(1200, 1200),
            IppResolution(600, 600),
            IppResolution(600, 600),
          ],
        ),
        IppAttribute.all(
          'print-quality-supported',
          IppValueTag.enumeration,
          const [3, 4, 5, 99],
        ),
        IppAttribute.all(
          'finishings-supported',
          IppValueTag.enumeration,
          const [3, 4],
        ),
        _keywords('multiple-document-handling-supported', [
          'separate-documents-collated-copies',
        ]),
        _keywords('ipp-versions-supported', ['1.1', '2.0']),
        IppAttribute.all(
          'operations-supported',
          IppValueTag.enumeration,
          const [2, 11],
        ),
        IppAttribute.all('marker-names', IppValueTag.name, const [
          'Cyan Toner',
          'Waste',
          'Drum',
        ]),
        _keywords('marker-types', ['toner', 'waste-toner']),
        IppAttribute.all('marker-colors', IppValueTag.name, const ['cyan']),
        IppAttribute.all('marker-levels', IppValueTag.integer, const [72, -2]),
      ]),
    );

    test('describes the printer', () {
      expect(printer.name, 'Office');
      expect(printer.info, 'Second floor');
      expect(printer.location, 'Kitchen');
      expect(printer.makeAndModel, 'Xerox VersaLink C7130');
      expect(printer.deviceId, 'MFG:Xerox;');
      expect(printer.uuid, 'abc-123');
      expect(printer.moreInfo, 'http://p/');
      expect(printer.ippVersions, ['1.1', '2.0']);
      expect(printer.operations, [2, 11]);
    });

    test('reports its state', () {
      expect(printer.state, IppPrinterState.processing);
      expect(printer.stateReasons, ['toner-low-warning']);
      expect(printer.isAcceptingJobs, isTrue);
      expect(printer.queuedJobCount, 2);
    });

    test('lists what it can print', () {
      expect(printer.documentFormats, ['application/pdf', 'image/urf']);
      expect(printer.defaultDocumentFormat, 'application/pdf');
      expect(printer.colorSupported, isTrue);
      expect(printer.colorModes, contains('monochrome'));
      expect(printer.sides, ['one-sided', 'two-sided-long-edge']);
      expect(printer.media, hasLength(2));
      expect(printer.defaultMedia, 'iso_a4_210x297mm');
      expect(printer.mediaTypes, ['stationery']);
      expect(printer.mediaSources, ['auto', 'tray-1']);
      expect(printer.maxCopies, 999);
      expect(printer.resolutionsDpi, [600, 1200]);
      expect(printer.qualities, ['draft', 'normal', 'high']);
      expect(printer.finishings, [4]);
      expect(printer.collationSupported, isTrue);
      expect(printer.supportsAirPrint, isTrue);
    });

    test('matches supplies up across the marker attributes', () {
      final markers = printer.markers;

      expect(markers, hasLength(3));
      expect(markers[0].name, 'Cyan Toner');
      expect(markers[0].type, 'toner');
      expect(markers[0].color, 'cyan');
      expect(markers[0].levelPercent, 72);
      expect(markers[1].type, 'waste-toner');
      expect(markers[1].color, isNull);
      expect(markers[1].levelPercent, isNull, reason: 'negative means unknown');
      expect(markers[2].type, isNull);
      expect(markers[2].levelPercent, isNull);
    });

    test('answers sensibly for a printer that says almost nothing', () {
      final quiet = IppPrinterAttributes(
        IppGroup(IppGroupTag.printer, [
          IppAttribute.single('printer-name', IppValueTag.name, ''),
          _keywords('print-color-mode-supported', ['monochrome']),
        ]),
      );

      expect(quiet.name, isNull);
      expect(quiet.uuid, isNull);
      expect(quiet.state, IppPrinterState.unknown);
      expect(quiet.stateReasons, isEmpty);
      expect(quiet.isAcceptingJobs, isNull);
      expect(quiet.queuedJobCount, isNull);
      expect(quiet.colorSupported, isFalse);
      expect(quiet.maxCopies, isNull);
      expect(quiet.resolutionsDpi, isEmpty);
      expect(quiet.qualities, isEmpty);
      expect(quiet.finishings, isEmpty);
      expect(quiet.collationSupported, isFalse);
      expect(quiet.supportsAirPrint, isFalse);
      expect(quiet.markers, isEmpty);
      expect(quiet.operations, isEmpty);
    });

    test('infers colour from the colour modes', () {
      final printer = IppPrinterAttributes(
        IppGroup(IppGroupTag.printer, [
          _keywords('print-color-mode-supported', ['color', 'monochrome']),
          IppAttribute.single('urf-supported', IppValueTag.keyword, 'W8'),
        ]),
      );

      expect(printer.colorSupported, isTrue);
      expect(printer.supportsAirPrint, isTrue);
    });
  });

  group('states', () {
    test('printer states are read from their codes', () {
      expect(IppPrinterState.fromCode(3), IppPrinterState.idle);
      expect(IppPrinterState.fromCode(4), IppPrinterState.processing);
      expect(IppPrinterState.fromCode(5), IppPrinterState.stopped);
      expect(IppPrinterState.fromCode(null), IppPrinterState.unknown);
    });

    test('job states are read from their codes', () {
      expect([
        for (var code = 3; code <= 9; code++) IppJobState.fromCode(code),
      ], IppJobState.values.take(7));
      expect(IppJobState.fromCode(1), IppJobState.unknown);
    });

    test('a job is finished once it cannot change', () {
      final finished = IppJobState.values.where((state) => state.isFinished);

      expect(finished, [
        IppJobState.canceled,
        IppJobState.aborted,
        IppJobState.completed,
      ]);
    });
  });

  group('IppJob.fromGroup', () {
    test('reads a job', () {
      final job = IppJob.fromGroup(
        IppGroup(IppGroupTag.job, [
          IppAttribute.single('job-id', IppValueTag.integer, 12),
          IppAttribute.single(
            'job-uri',
            IppValueTag.uri,
            'ipp://p/ipp/print/12',
          ),
          IppAttribute.single('job-state', IppValueTag.enumeration, 6),
          _keywords('job-state-reasons', ['none', 'media-jam-error']),
          IppAttribute.single('job-name', IppValueTag.name, 'Report'),
        ]),
      );

      expect(job.id, 12);
      expect(job.uri, 'ipp://p/ipp/print/12');
      expect(job.state, IppJobState.processingStopped);
      expect(job.stateReasons, ['media-jam-error']);
      expect(job.name, 'Report');
    });

    test('tolerates a job with nothing in it', () {
      final job = IppJob.fromGroup(IppGroup(IppGroupTag.job));

      expect(job.id, 0);
      expect(job.uri, isNull);
      expect(job.state, IppJobState.unknown);
      expect(job.stateReasons, isEmpty);
      expect(job.name, isNull);
    });
  });

  group('IppJobOptions', () {
    test('sends nothing the caller did not choose', () {
      expect(const IppJobOptions().toJobAttributes(), isEmpty);
      expect(const IppJobOptions().documentFormat, 'application/pdf');
    });

    test('turns every choice into a job attribute', () {
      final attributes = {
        for (final attribute in const IppJobOptions(
          copies: 2,
          sides: 'two-sided-long-edge',
          colorMode: 'monochrome',
          media: 'iso_a4_210x297mm',
          mediaSource: 'tray-1',
          mediaType: 'stationery',
          quality: 'high',
          orientation: 'landscape',
          pageRanges: [IppRange(1, 3)],
          collate: true,
          scaling: 'fit',
        ).toJobAttributes())
          attribute.name: attribute,
      };

      expect(attributes['copies']!.first, 2);
      expect(attributes['sides']!.first, 'two-sided-long-edge');
      expect(attributes['print-color-mode']!.first, 'monochrome');
      expect(attributes['media']!.first, 'iso_a4_210x297mm');
      expect(attributes['media-source']!.first, 'tray-1');
      expect(attributes['media-type']!.first, 'stationery');
      expect(attributes['print-quality']!.first, 5);
      expect(attributes['orientation-requested']!.first, 4);
      expect(attributes['page-ranges']!.first, const IppRange(1, 3));
      expect(
        attributes['multiple-document-handling']!.first,
        'separate-documents-collated-copies',
      );
      expect(attributes['print-scaling']!.first, 'fit');
    });

    test('maps each quality and orientation, and skips unknown ones', () {
      int? quality(String value) {
        final found = IppJobOptions(quality: value).toJobAttributes();
        return found.isEmpty ? null : found.single.first! as int;
      }

      int? orientation(String value) {
        final found = IppJobOptions(orientation: value).toJobAttributes();
        return found.isEmpty ? null : found.single.first! as int;
      }

      expect(quality('draft'), 3);
      expect(quality('normal'), 4);
      expect(quality('best'), isNull);
      expect(orientation('portrait'), 3);
      expect(orientation('sideways'), isNull);
      expect(
        const IppJobOptions(collate: false).toJobAttributes().single.first,
        'separate-documents-uncollated-copies',
      );
      expect(const IppJobOptions(pageRanges: []).toJobAttributes(), isEmpty);
    });
  });
}
