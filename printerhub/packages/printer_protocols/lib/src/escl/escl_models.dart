import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

/// What one way of feeding the scanner (the glass, or the feeder) can do.
@immutable
class EsclInput {
  const new({
    required this.maxWidthMm,
    required this.maxHeightMm,
    required this.colorModes,
    required this.documentFormats,
    required this.resolutionsDpi,
  });

  /// eSCL measures in three-hundredths of an inch.
  static double _toMm(int units) => units / 300 * 25.4;

  static EsclInput? parse(XmlElement? caps) {
    if (caps == null) return null;

    int number(String name) {
      return int.tryParse(_firstText(caps, name) ?? '') ?? 0;
    }

    return EsclInput(
      maxWidthMm: _toMm(number('MaxWidth')),
      maxHeightMm: _toMm(number('MaxHeight')),
      colorModes: _texts(caps, 'ColorMode').toSet().toList(),
      documentFormats: {
        ..._texts(caps, 'DocumentFormat'),
        ..._texts(caps, 'DocumentFormatExt'),
      }.toList(),
      resolutionsDpi: {
        for (final value in _texts(caps, 'XResolution')) ?int.tryParse(value),
      }.toList()..sort(),
    );
  }

  final double maxWidthMm;
  final double maxHeightMm;

  /// `RGB24` (colour), `Grayscale8`, `BlackAndWhite1`.
  final List<String> colorModes;

  /// MIME types, such as `application/pdf` and `image/jpeg`.
  final List<String> documentFormats;
  final List<int> resolutionsDpi;
}

/// What the scanner can do, from `ScannerCapabilities`.
@immutable
class EsclCapabilities {
  const new({
    this.makeAndModel,
    this.serialNumber,
    this.uuid,
    this.platen,
    this.feeder,
    this.feederDuplex = false,
  });

  factory parse(String xml) {
    final root = XmlDocument.parse(xml).rootElement;
    final feeder = _first(root, 'Adf');
    return EsclCapabilities(
      makeAndModel: _firstText(root, 'MakeAndModel'),
      serialNumber: _firstText(root, 'SerialNumber'),
      uuid: _firstText(root, 'UUID'),
      platen: EsclInput.parse(
        _first(_first(root, 'Platen'), 'PlatenInputCaps'),
      ),
      feeder: EsclInput.parse(_first(feeder, 'AdfSimplexInputCaps')),
      feederDuplex: _first(feeder, 'AdfDuplexInputCaps') != null,
    );
  }

  final String? makeAndModel;
  final String? serialNumber;
  final String? uuid;

  /// The glass. Null when the device has none.
  final EsclInput? platen;

  /// The document feeder. Null when the device has none.
  final EsclInput? feeder;

  /// True when the feeder scans both sides.
  final bool feederDuplex;
}

enum EsclScannerState { idle, processing, stopped, down, unknown }

/// What the scanner is doing, from `ScannerStatus`.
@immutable
class EsclStatus {
  const new({required this.state, this.feederState});

  factory parse(String xml) {
    final root = XmlDocument.parse(xml).rootElement;
    return EsclStatus(
      state: switch (_firstText(root, 'State')) {
        'Idle' => EsclScannerState.idle,
        'Processing' || 'Testing' => EsclScannerState.processing,
        'Stopped' => EsclScannerState.stopped,
        'Down' => EsclScannerState.down,
        _ => EsclScannerState.unknown,
      },
      feederState: _firstText(root, 'AdfState'),
    );
  }

  final EsclScannerState state;

  /// Such as `ScannerAdfLoaded`, `ScannerAdfEmpty`, `ScannerAdfJam`. Null
  /// without a feeder.
  final String? feederState;

  bool get feederEmpty => feederState == 'ScannerAdfEmpty';
  bool get feederJammed => feederState == 'ScannerAdfJam';
}

/// What to scan and how.
@immutable
class EsclScanSettings {
  const new({
    this.fromFeeder = false,
    this.duplex = false,
    this.colorMode = 'RGB24',
    this.resolutionDpi = 300,
    this.documentFormat = 'application/pdf',
    this.widthMm = 210,
    this.heightMm = 297,
  });

  /// False scans from the glass.
  final bool fromFeeder;

  /// Both sides. Only with [fromFeeder], on a feeder that can.
  final bool duplex;
  final String colorMode;
  final int resolutionDpi;
  final String documentFormat;

  /// The area to scan, from the top left corner. A4 by default.
  final double widthMm;
  final double heightMm;

  static int _units(double mm) => (mm / 25.4 * 300).round();

  /// The `ScanSettings` document for these settings.
  String toXml() {
    final builder = XmlBuilder()
      ..processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'scan:ScanSettings',
      namespaceUris: const {
        'scan': 'http://schemas.hp.com/imaging/escl/2011/05/03',
        'pwg': 'http://www.pwg.org/schemas/2010/12/sm',
      },
      nest: () {
        builder
          ..element('pwg:Version', nest: '2.6')
          ..element(
            'pwg:ScanRegions',
            nest: () => builder.element(
              'pwg:ScanRegion',
              nest: () => builder
                ..element('pwg:XOffset', nest: 0)
                ..element('pwg:YOffset', nest: 0)
                ..element('pwg:Width', nest: _units(widthMm))
                ..element('pwg:Height', nest: _units(heightMm))
                ..element(
                  'pwg:ContentRegionUnits',
                  nest: 'escl:ThreeHundredthsOfInches',
                ),
            ),
          )
          ..element('pwg:InputSource', nest: fromFeeder ? 'Feeder' : 'Platen')
          ..element('scan:ColorMode', nest: colorMode)
          ..element('scan:XResolution', nest: resolutionDpi)
          ..element('scan:YResolution', nest: resolutionDpi)
          // Old firmware reads the first, new firmware the second.
          ..element('pwg:DocumentFormat', nest: documentFormat)
          ..element('scan:DocumentFormatExt', nest: documentFormat);
        if (fromFeeder) builder.element('scan:Duplex', nest: duplex);
      },
    );
    return builder.buildDocument().toXmlString();
  }
}

XmlElement? _first(XmlElement? parent, String localName) {
  if (parent == null) return null;
  for (final element in parent.descendantElements) {
    if (element.name.local == localName) return element;
  }
  return null;
}

String? _firstText(XmlElement parent, String localName) {
  final text = _first(parent, localName)?.innerText.trim();
  return text == null || text.isEmpty ? null : text;
}

Iterable<String> _texts(XmlElement parent, String localName) sync* {
  for (final element in parent.descendantElements) {
    if (element.name.local == localName) yield element.innerText.trim();
  }
}
