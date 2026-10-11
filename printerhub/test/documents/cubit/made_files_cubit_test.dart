import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/documents/documents.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() => backend = TestBackend());
  tearDown(() => backend.close());

  File pdf(String name) => File(pickedPdfFile(backend.scans, name: name).path);
  File picture(String name) =>
      File(pickedPicture(backend.scans, name: name).path);

  MadeFilesCubit build(List<File> files) {
    final cubit = MadeFilesCubit(renderer: backend.renderer, files: files);
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts with nothing drawn', () {
    expect(build([pdf('Sign.pdf')]).state, isEmpty);
  });

  test('shows a picture as itself, and a PDF by its first page, drawn '
      'once', () async {
    backend.renderer.firstPage = tinyPng;
    final photo = picture('Resume 1.jpg');
    final sign = pdf('Sign.pdf');

    final cubit = build([photo, sign]);
    await cubit.load();

    expect(cubit.state[photo.path], photo.path);
    final drawn = File(cubit.state[sign.path]!);
    expect(drawn.path, '${sign.path}.thumbnail.png');
    expect(drawn.readAsBytesSync(), tinyPng);

    // The drawing is kept: it is not made again.
    backend.renderer.unreadable = true;
    final again = build([sign]);
    await again.load();
    expect(again.state[sign.path], drawn.path);
  });

  test('leaves a file it cannot draw to the sign for its kind', () async {
    // A PDF with no first page to show, one that cannot be read, and a
    // kind of file that is never drawn.
    final blank = pdf('Blank.pdf');
    final words = File('${backend.scans.path}/Words.txt')
      ..writeAsStringSync('words');
    final cubit = build([blank, words]);
    await cubit.load();
    expect(cubit.state, isEmpty);

    backend.renderer.unreadable = true;
    final broken = build([pdf('Broken.pdf')]);
    await broken.load();
    expect(broken.state, isEmpty);
  });

  test('says nothing once the screen has gone', () async {
    final photo = picture('Resume 1.jpg');
    final cubit = MadeFilesCubit(renderer: backend.renderer, files: [photo]);
    final loading = cubit.load();
    await cubit.close();
    await loading;

    expect(cubit.state, isEmpty);
  });
}
