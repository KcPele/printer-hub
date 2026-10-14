import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:printerhub/tools/tools.dart';

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('pdf_lock'));
  tearDown(() => directory.deleteSync(recursive: true));

  String hex(List<int> bytes) =>
      [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();

  test('RC4 gives the published answers', () {
    // The test vectors every RC4 implementation is held to.
    expect(
      hex(rc4(ascii.encode('Key'), ascii.encode('Plaintext'))),
      'bbf316e8d940af0ad3',
    );
    expect(hex(rc4(ascii.encode('Wiki'), ascii.encode('pedia'))), '1021bf0420');
    expect(
      hex(rc4(ascii.encode('Secret'), ascii.encode('Attack at dawn'))),
      '45a01f645fc35b383552544b9bf5',
    );
  });

  test('locks a PDF: it says it is encrypted, and its pages are not '
      'readable without the password', () async {
    final page = img.encodeJpg(img.Image(width: 30, height: 40));

    final file = await lockedPdf(
      pages: [page, page],
      password: 'open sesame',
      name: 'Locked today',
      directory: directory,
    );

    expect(file.path, endsWith('/Locked today.pdf'));
    final bytes = file.readAsBytesSync();
    final text = latin1.decode(bytes);
    expect(text, startsWith('%PDF-'));
    expect(text, contains('/Encrypt'));
    expect(text, contains('/Standard'));
    // The pictures are there, but not as pictures anyone can read: a
    // JPEG's own marker never shows.
    expect(text, isNot(contains('JFIF')));
  });

  test('gives each object a key of its own, and takes any password', () {
    final document = PdfDocument();
    final long = PasswordLock(
      document,
      password: 'a password longer than thirty-two letters, and ünïcode ✓',
    );
    final input = Uint8List.fromList(ascii.encode('the same words'));

    final first = long.encrypt(input, PdfInfo(document));
    final second = long.encrypt(input, PdfInfo(document));

    expect(first, isNot(input));
    expect(first, isNot(second));
    expect(long.key, hasLength(16));
    // The same password on the same document gives the same key.
    expect(
      PasswordLock(
        document,
        password: 'a password longer than thirty-two letters, and ünïcode ✓',
      ).key,
      long.key,
    );
    expect(PasswordLock(document, password: 'other').key, isNot(long.key));
  });
}
