// Talks to the phone's share sheet through a plugin, which only runs on a
// device. `FakeScanSharer` stands in for it in tests.
// coverage:ignore-file
import 'dart:io';

import 'package:printerhub/scan/scan_output.dart';
import 'package:share_plus/share_plus.dart';

/// Shares scans through the phone's own share sheet.
class SharePlusScanSharer implements ScanSharer {
  const new();

  @override
  Future<void> share(List<File> files, {required String name}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final file in files) XFile(file.path)],
        subject: name,
      ),
    );
  }
}
