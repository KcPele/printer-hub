// Talks to the phone's NFC reader through a plugin, so it cannot run in a
// unit test. What it feeds, textOfNdefRecord and ScannedCode, is tested in
// full.
// coverage:ignore-file

import 'dart:async';
import 'dart:convert';

import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:printer_discovery/src/finders.dart';
import 'package:printer_discovery/src/ndef_text.dart';

/// Reads NFC tags with the phone's own reader.
class PluginNfcReader implements NfcReader {
  const new();

  @override
  Future<bool> get isAvailable async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } on Object {
      return false;
    }
  }

  @override
  Future<String?> read() {
    final result = Completer<String?>();

    Future<void> finish(String? text, [Object? error]) async {
      if (result.isCompleted) return;
      if (error == null) {
        result.complete(text);
      } else {
        result.completeError(error);
      }
      await cancel();
    }

    unawaited(
      NfcManager.instance
          .startSession(
            pollingOptions: {NfcPollingOption.iso14443},
            onDiscovered: (tag) async {
              try {
                final ndef = Ndef.from(tag);
                final message = ndef?.cachedMessage ?? await ndef?.read();
                String? text;
                for (final record in message?.records ?? const <NdefRecord>[]) {
                  text = textOfNdefRecord(
                    type: utf8.decode(record.type, allowMalformed: true),
                    payload: record.payload,
                  );
                  if (text != null) break;
                }
                await finish(text);
              } on Object catch (error) {
                await finish(null, error);
              }
            },
          )
          .catchError((Object error) => finish(null, error)),
    );
    return result.future;
  }

  @override
  Future<void> cancel() async {
    try {
      await NfcManager.instance.stopSession();
    } on Object {
      // No session was open.
    }
  }
}
