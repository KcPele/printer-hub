// Talks to the phone's own text recognition over a channel, which only
// exists on a device. `FakeScanTextReader` stands in for it in tests.
// coverage:ignore-file
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:printerhub/scan/scan_output.dart';

/// Reads text with what the phone has: Vision on iOS (`AppDelegate.swift`)
/// and ML Kit's bundled model on Android (`MainActivity.kt`). Neither
/// sends a page anywhere.
class ChannelScanTextReader implements ScanTextReader {
  const new();

  static const MethodChannel _channel = MethodChannel('printerhub/scan_text');

  @override
  Future<String> read(List<File> pictures) async {
    final text = await _channel.invokeMethod<String>('read', [
      for (final picture in pictures) picture.path,
    ]);
    return text ?? '';
  }
}
