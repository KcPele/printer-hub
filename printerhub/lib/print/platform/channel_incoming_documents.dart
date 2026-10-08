// Talks to the native side of the app over a channel, which only exists on
// a device. `FakeIncomingDocuments` stands in for it in tests.
// coverage:ignore-file
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:printerhub/print/documents.dart';

/// Files handed to the app by another one, as `SceneDelegate.swift` and
/// `MainActivity.kt` pass them on. Each arrives as a path to the app's own
/// copy of the file.
class ChannelIncomingDocuments implements IncomingDocuments {
  new();

  static const MethodChannel _channel = MethodChannel(
    'printerhub/incoming_files',
  );

  late final StreamController<PickedDocument> _documents =
      StreamController<PickedDocument>(onListen: _listen);

  @override
  Stream<PickedDocument> get documents => _documents.stream;

  Future<void> _listen() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'opened') _add(call.arguments as String);
    });
    try {
      // What arrived before the app was ready for it.
      final waiting = await _channel.invokeListMethod<String>('listen');
      waiting?.forEach(_add);
    } on MissingPluginException {
      // A platform with no native side for this.
    }
  }

  void _add(String path) {
    final file = File(path);
    if (file.existsSync()) _documents.add(PickedDocument.fromFile(file));
  }
}
