import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:printerhub/scan/scan_output.dart';

/// The most pages one long picture is made of. Past this it is too tall
/// for a phone to show or a chat to take.
const int maxLongPicturePages = 20;

/// A page could not be read as a picture.
class UnreadablePage implements Exception {
  const new();
}

/// Writes each of [pages], PNG pictures of a document's pages, as a JPEG
/// in [directory]: `name.jpg`, or `name 1.jpg`, `name 2.jpg` and so on.
///
/// The pictures are worked on away from the screen's thread: a page is
/// millions of pixels.
Future<List<File>> pagesAsPictures({
  required List<Uint8List> pages,
  required String name,
  required Directory directory,
}) async {
  final base = '${directory.path}/${scanFileName(name)}';
  final files = <File>[];
  for (final (index, page) in pages.indexed) {
    final jpeg = await Isolate.run(() => _jpeg(page));
    final file = File('$base${pages.length == 1 ? '' : ' ${index + 1}'}.jpg');
    await file.writeAsBytes(jpeg, flush: true);
    files.add(file);
  }
  return files;
}

/// Joins [pages], PNG pictures of a document's pages, top to bottom into
/// one tall JPEG in [directory], each as wide as the narrowest.
Future<File> pagesAsLongPicture({
  required List<Uint8List> pages,
  required String name,
  required Directory directory,
}) async {
  final jpeg = await Isolate.run(() => _stacked(pages));
  final file = File('${directory.path}/${scanFileName(name)}.jpg');
  await file.writeAsBytes(jpeg, flush: true);
  return file;
}

/// Writes [text] as a plain text file in [directory].
Future<File> textAsFile({
  required String text,
  required String name,
  required Directory directory,
}) async {
  final file = File('${directory.path}/${scanFileName(name)}.txt');
  await file.writeAsString(text, flush: true);
  return file;
}

img.Image _decoded(Uint8List page) {
  final img.Image? picture;
  try {
    picture = img.decodePng(page);
  } on Object {
    // The decoder gives up on bytes that are not a picture in its own ways.
    throw const UnreadablePage();
  }
  if (picture == null) throw const UnreadablePage();
  return picture;
}

Uint8List _jpeg(Uint8List page) => img.encodeJpg(_decoded(page), quality: 85);

Uint8List _stacked(List<Uint8List> pages) {
  final pictures = [for (final page in pages) _decoded(page)];
  final width = pictures
      .map((picture) => picture.width)
      .reduce((a, b) => a < b ? a : b);
  final fitted = [
    for (final picture in pictures)
      if (picture.width == width)
        picture
      else
        img.copyResize(picture, width: width),
  ];
  final long = img.Image(
    width: width,
    height: fitted.fold(0, (height, picture) => height + picture.height),
  );
  var top = 0;
  for (final picture in fitted) {
    img.compositeImage(long, picture, dstY: top);
    top += picture.height;
  }
  return img.encodeJpg(long, quality: 85);
}
