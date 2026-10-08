// Talks to the phone's document camera over a channel, which only exists
// on a device. `FakePageCamera` stands in for it in tests.
// coverage:ignore-file
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:printerhub/scan/scan_output.dart';

/// The document camera the phone comes with: VisionKit on iOS
/// (`AppDelegate.swift`) and the ML Kit document scanner on Android
/// (`MainActivity.kt`). Both find the page, straighten it, and take as
/// many pages as the person likes.
class ChannelPageCamera implements PageCamera {
  const new _({required this.available});

  static const MethodChannel _channel = MethodChannel('printerhub/page_camera');

  /// Asks the phone whether it has a document camera, once, as the app
  /// starts.
  static Future<ChannelPageCamera> find() async {
    try {
      final available = await _channel.invokeMethod<bool>('available');
      return ChannelPageCamera._(available: available ?? false);
    } on PlatformException {
      return const ChannelPageCamera._(available: false);
    } on MissingPluginException {
      return const ChannelPageCamera._(available: false);
    }
  }

  @override
  final bool available;

  @override
  Future<List<File>> capture() async {
    final paths = await _channel.invokeListMethod<String>('capture');
    return [for (final path in paths ?? const <String>[]) File(path)];
  }
}
