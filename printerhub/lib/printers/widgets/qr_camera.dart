// Shows the phone's camera through a plugin, which a widget test cannot
// run. The screen that uses it is tested with a stand-in that hands it
// codes directly.
// coverage:ignore-file

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The camera, reading QR codes.
class QrCamera extends StatelessWidget {
  const new({required this.onCode, super.key});

  final ValueChanged<String> onCode;

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final text = barcode.rawValue;
          if (text != null && text.isNotEmpty) {
            onCode(text);
            return;
          }
        }
      },
    );
  }
}
