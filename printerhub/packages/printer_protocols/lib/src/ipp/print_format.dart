import 'package:meta/meta.dart';
import 'package:printer_protocols/src/ipp/ipp_models.dart';
import 'package:printer_protocols/src/ipp/pwg_media.dart';
import 'package:printer_protocols/src/raster/raster_encoder.dart';

/// The form a document is sent to a printer in.
@immutable
sealed class PrintFormat {
  const new();

  /// What goes in `document-format`.
  String get mimeType;
}

/// The printer reads the file itself: send it untouched.
final class DirectFormat extends PrintFormat {
  const new(this.mimeType);

  @override
  final String mimeType;

  @override
  bool operator ==(Object other) {
    return other is DirectFormat && other.mimeType == mimeType;
  }

  @override
  int get hashCode => mimeType.hashCode;

  @override
  String toString() => 'DirectFormat($mimeType)';
}

/// The printer takes pictures of pages: draw each page and send the pixels.
final class RasterTarget extends PrintFormat {
  const new({
    required this.format,
    required this.color,
    required this.resolutionDpi,
    this.sheetBack = SheetBack.normal,
  });

  final RasterFormat format;
  final RasterColor color;
  final int resolutionDpi;
  final SheetBack sheetBack;

  @override
  String get mimeType => format.mimeType;

  /// What to hand a [RasterEncoder] for a document of [pageCount] pages on
  /// [media].
  RasterDocument document({
    required PwgMedia media,
    required int pageCount,
    RasterSides sides = RasterSides.oneSided,
    int? quality,
  }) {
    return RasterDocument(
      format: format,
      color: color,
      resolutionDpi: resolutionDpi,
      widthPx: media.widthPx(resolutionDpi),
      heightPx: media.heightPx(resolutionDpi),
      pageCount: pageCount,
      sides: sides,
      sheetBack: sheetBack,
      quality: quality,
      mediaName: media.name,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RasterTarget &&
        other.format == format &&
        other.color == color &&
        other.resolutionDpi == resolutionDpi &&
        other.sheetBack == sheetBack;
  }

  @override
  int get hashCode => Object.hash(format, color, resolutionDpi, sheetBack);

  @override
  String toString() =>
      'RasterTarget(${format.name}, ${color.name}, $resolutionDpi dpi, '
      '${sheetBack.name})';
}

/// The resolution pages are drawn at when the printer offers it. More than
/// this makes a page four times the size for no gain a reader can see.
const int _preferredDpi = 300;

/// Chooses how to send a document of [sourceType] to [printer].
///
/// A printer that reads the file's own format gets the file. Otherwise the
/// pages are drawn, as PWG Raster where the printer takes it and as Apple
/// Raster where it does not. Null means the printer takes nothing the app
/// can make.
///
/// PDF cannot be taken for granted: the IPP Everywhere standard only
/// recommends it, and many home printers do without.
PrintFormat? choosePrintFormat(
  IppPrinterAttributes printer, {
  required String sourceType,
  bool color = true,
}) {
  final formats = printer.documentFormats;
  if (_sentAsIs.contains(sourceType) && formats.contains(sourceType)) {
    return DirectFormat(sourceType);
  }
  final wantColor = color && printer.colorSupported;

  if (formats.contains(RasterFormat.pwg.mimeType)) {
    final types = printer.pwgRasterTypes;
    final rasterColor = wantColor && types.contains('srgb_8')
        ? RasterColor.srgb8
        : types.contains('sgray_8')
        ? RasterColor.sgray8
        : types.contains('srgb_8')
        ? RasterColor.srgb8
        : null;
    final dpi = _chooseDpi(printer.pwgRasterResolutionsDpi);
    if (rasterColor != null && dpi != null) {
      return RasterTarget(
        format: RasterFormat.pwg,
        color: rasterColor,
        resolutionDpi: dpi,
        sheetBack: printer.pwgRasterSheetBack,
      );
    }
  }

  if (printer.supportsAirPrint) {
    // Every AirPrint printer takes grey at 300 dpi; the rest it lists.
    final urf = printer.urf;
    return RasterTarget(
      format: RasterFormat.urf,
      color: wantColor && urf.color ? RasterColor.srgb8 : RasterColor.sgray8,
      resolutionDpi: _chooseDpi(urf.resolutionsDpi) ?? _preferredDpi,
      sheetBack: urf.sheetBack,
    );
  }
  return null;
}

/// The formats worth sending untouched when the printer lists them.
const Set<String> _sentAsIs = {'application/pdf', 'image/jpeg'};

/// 300 when offered, else the next above it, else the best there is.
int? _chooseDpi(List<int> offered) {
  if (offered.isEmpty) return null;
  final sorted = [...offered]..sort();
  for (final dpi in sorted) {
    if (dpi >= _preferredDpi) return dpi;
  }
  return sorted.last;
}
