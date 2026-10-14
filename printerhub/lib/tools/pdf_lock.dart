import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
// The PDF types an encryption is written in are kept here: the library
// leaves encryption to extensions such as this one.
// ignore: implementation_imports
import 'package:pdf/src/priv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printerhub/scan/scan_output.dart';

/// The 32 bytes a PDF password is filled out with, from the PDF standard.
final Uint8List _fill = Uint8List.fromList(const [
  0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, //
  0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
  0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
  0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
]);

/// What a reader may do once the PDF is open: everything. The password
/// is to keep it closed, not to hobble it.
const int _allowed = -4;

/// RC4 over [data] with [key]: the cipher the PDF standard's 128-bit
/// password protection uses.
Uint8List rc4(List<int> key, List<int> data) {
  final s = List<int>.generate(256, (i) => i);
  var j = 0;
  for (var i = 0; i < 256; i++) {
    j = (j + s[i] + key[i % key.length]) & 0xFF;
    final t = s[i];
    s[i] = s[j];
    s[j] = t;
  }
  final out = Uint8List(data.length);
  var i = 0;
  j = 0;
  for (var n = 0; n < data.length; n++) {
    i = (i + 1) & 0xFF;
    j = (j + s[i]) & 0xFF;
    final t = s[i];
    s[i] = s[j];
    s[j] = t;
    out[n] = data[n] ^ s[(s[i] + s[j]) & 0xFF];
  }
  return out;
}

/// [password] as the standard takes it: its first 32 bytes, filled out
/// to 32.
Uint8List _padded(String password) {
  final bytes = latin1.encode(
    String.fromCharCodes(password.runes.where((rune) => rune < 256)),
  );
  return Uint8List.fromList([
    ...bytes.take(32),
    ..._fill.take(32 - bytes.take(32).length),
  ]);
}

List<int> _md5(List<int> data) => md5.convert(data).bytes;

/// RC4 with [key], then nineteen times more with the key changed each
/// time, as revision 3 of the standard asks.
Uint8List _rounds(List<int> key, List<int> data) {
  var out = rc4(key, data);
  for (var round = 1; round <= 19; round++) {
    out = rc4([for (final byte in key) byte ^ round], out);
  }
  return out;
}

/// The protection a PDF is given when it is locked: the standard
/// security handler, revision 3, 128-bit keys. Every PDF reader asks for
/// the password before it shows a page.
class PasswordLock extends PdfEncryption {
  new(PdfDocument document, {required String password}) : super(document) {
    final id = document.documentID;
    final user = _padded(password);

    // The owner's password is the same: whoever opens it may do anything.
    var ownerHash = _md5(user);
    for (var i = 0; i < 50; i++) {
      ownerHash = _md5(ownerHash);
    }
    final owner = _rounds(ownerHash.sublist(0, 16), user);

    var hash = _md5([
      ...user,
      ...owner,
      ...(ByteData(
        4,
      )..setInt32(0, _allowed, Endian.little)).buffer.asUint8List(),
      ...id,
    ]);
    for (var i = 0; i < 50; i++) {
      hash = _md5(hash.sublist(0, 16));
    }
    key = Uint8List.fromList(hash.sublist(0, 16));

    final check = _rounds(key, _md5([..._fill, ...id]));

    params
      ..['/Filter'] = const PdfName('/Standard')
      ..['/V'] = const PdfNum(2)
      ..['/R'] = const PdfNum(3)
      ..['/Length'] = const PdfNum(128)
      ..['/P'] = const PdfNum(_allowed)
      ..['/O'] = PdfString(
        owner,
        format: PdfStringFormat.binary,
        encrypted: false,
      )
      ..['/U'] = PdfString(
        Uint8List.fromList([...check, ...Uint8List(16)]),
        format: PdfStringFormat.binary,
        encrypted: false,
      );
  }

  /// The document's key, from the password.
  late final Uint8List key;

  @override
  Uint8List encrypt(Uint8List input, PdfObjectBase object) {
    // Each object has its own key, from its number.
    final objectKey = _md5([
      ...key,
      object.objser & 0xFF,
      (object.objser >> 8) & 0xFF,
      (object.objser >> 16) & 0xFF,
      object.objgen & 0xFF,
      (object.objgen >> 8) & 0xFF,
    ]).sublist(0, 16);
    return rc4(objectKey, input);
  }
}

/// [pages], pictures of a PDF's pages, as a new PDF that opens only with
/// [password], written to [directory]. Each page keeps its picture's
/// shape.
Future<File> lockedPdf({
  required List<Uint8List> pages,
  required String password,
  required String name,
  required Directory directory,
}) async {
  final document = pw.Document(title: name);
  document.document.encryption = PasswordLock(
    document.document,
    password: password,
  );
  for (final page in pages) {
    final picture = pw.MemoryImage(page);
    // A page the size it was drawn at, at 150 dots to the inch.
    final width = (picture.width ?? 1240) / 150 * PdfPageFormat.inch;
    final height = (picture.height ?? 1754) / 150 * PdfPageFormat.inch;
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, height),
        build: (_) => pw.Image(picture, fit: pw.BoxFit.fill),
      ),
    );
  }
  final file = File('${directory.path}/${scanFileName(name)}.pdf');
  await file.writeAsBytes(await document.save(), flush: true);
  return file;
}
