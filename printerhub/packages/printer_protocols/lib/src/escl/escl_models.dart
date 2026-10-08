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
    this.usesDocumentFormatExt = false,
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
      usesDocumentFormatExt: _first(caps, 'DocumentFormatExt') != null,
    );
  }

  final double maxWidthMm;
  final double maxHeightMm;

  /// `RGB24` (colour), `Grayscale8`, `BlackAndWhite1`.
  final List<String> colorModes;

  /// MIME types, such as `application/pdf` and `image/jpeg`.
  final List<String> documentFormats;
  final List<int> resolutionsDpi;

  /// True when the scanner lists formats the newer way, and so expects to
  /// be asked the newer way.
  final bool usesDocumentFormatExt;

  /// Settings this input will accept, as near to what is asked as it gets.
  ///
  /// A scanner refuses a resolution, colour mode, format, or area it did
  /// not offer, so what the person chose is fitted to what was offered.
  EsclScanSettings settings({
    required bool fromFeeder,
    bool color = true,
    bool duplex = false,
    int resolutionDpi = 300,
    String documentFormat = 'application/pdf',
    double widthMm = 210,
    double heightMm = 297,
  }) {
    const colorOrder = ['RGB24', 'Grayscale8', 'BlackAndWhite1'];
    const grayOrder = ['Grayscale8', 'BlackAndWhite1', 'RGB24'];
    final mode = (color ? colorOrder : grayOrder).firstWhere(
      colorModes.contains,
      orElse: () => colorModes.firstOrNull ?? 'RGB24',
    );

    var dpi = resolutionDpi;
    if (resolutionsDpi.isNotEmpty && !resolutionsDpi.contains(dpi)) {
      dpi = resolutionsDpi.reduce(
        (best, next) =>
            (next - resolutionDpi).abs() < (best - resolutionDpi).abs()
            ? next
            : best,
      );
    }

    final format =
        documentFormats.isEmpty || documentFormats.contains(documentFormat)
        ? documentFormat
        : const ['image/jpeg', 'application/pdf'].firstWhere(
            documentFormats.contains,
            orElse: () => documentFormats.first,
          );

    return EsclScanSettings(
      fromFeeder: fromFeeder,
      duplex: fromFeeder && duplex,
      colorMode: mode,
      resolutionDpi: dpi,
      documentFormat: format,
      widthMm: maxWidthMm > 0 && widthMm > maxWidthMm ? maxWidthMm : widthMm,
      heightMm: maxHeightMm > 0 && heightMm > maxHeightMm
          ? maxHeightMm
          : heightMm,
      useDocumentFormatExt: usesDocumentFormatExt,
    );
  }
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

  bool get feederLoaded => feederState == 'ScannerAdfLoaded';
  bool get feederEmpty => feederState == 'ScannerAdfEmpty';
  bool get feederJammed => feederState == 'ScannerAdfJam';
  bool get feederOpen => feederState == 'ScannerAdfDoorOpen';
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
    this.useDocumentFormatExt = false,
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

  /// Names the format the newer way as well, for a scanner that lists its
  /// formats that way. One that does not is not sent a word it may not
  /// know.
  final bool useDocumentFormatExt;

  static int _units(double mm) => (mm / 25.4 * 300).round();

  /// The `ScanSettings` document for these settings.
  String toXml() {
    final builder = XmlBuilder()
      ..processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'scan:ScanSettings',
      // Declared as plain attributes, which every version of the xml
      // package writes the same way.
      attributes: const {
        'xmlns:scan': 'http://schemas.hp.com/imaging/escl/2011/05/03',
        'xmlns:pwg': 'http://www.pwg.org/schemas/2010/12/sm',
      },
      nest: () {
        // The order below is the one scanners in use are known to accept;
        // some read the settings in order and ignore what is out of place.
        builder
          ..element('pwg:Version', nest: '2.0')
          ..element(
            'pwg:ScanRegions',
            nest: () => builder.element(
              'pwg:ScanRegion',
              nest: () => builder
                ..element(
                  'pwg:ContentRegionUnits',
                  nest: 'escl:ThreeHundredthsOfInches',
                )
                ..element('pwg:XOffset', nest: 0)
                ..element('pwg:YOffset', nest: 0)
                ..element('pwg:Width', nest: _units(widthMm))
                ..element('pwg:Height', nest: _units(heightMm)),
            ),
          )
          ..element('pwg:InputSource', nest: fromFeeder ? 'Feeder' : 'Platen')
          ..element('scan:ColorMode', nest: colorMode)
          ..element('pwg:DocumentFormat', nest: documentFormat);
        if (useDocumentFormatExt) {
          builder.element('scan:DocumentFormatExt', nest: documentFormat);
        }
        builder
          ..element('scan:XResolution', nest: resolutionDpi)
          ..element('scan:YResolution', nest: resolutionDpi);
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
