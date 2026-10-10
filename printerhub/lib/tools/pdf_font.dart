import 'package:flutter/services.dart';

/// Reads the font the app sets words in when it makes a PDF, so that
/// letters beyond plain Latin come out. Null when it cannot be read, and
/// then the PDF's own plain font is used.
typedef PdfFontLoader = Future<ByteData?> Function();

/// The app's own font for a PDF: Manrope, which ships with the app.
Future<ByteData?> pdfFont([AssetBundle? bundle]) async {
  try {
    return await (bundle ?? rootBundle).load(
      'packages/app_ui/assets/fonts/manrope/Manrope.ttf',
    );
  } on Object {
    return null;
  }
}
