import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/documents/documents.dart';

void main() {
  test('a file’s kind is told from its name', () {
    expect(mimeTypeOfName('Scan.pdf'), 'application/pdf');
    expect(mimeTypeOfName('Photo.JPG'), 'image/jpeg');
    expect(mimeTypeOfName('Photo.jpeg'), 'image/jpeg');
    expect(mimeTypeOfName('Page.png'), 'image/png');
    expect(mimeTypeOfName('Words.txt'), 'text/plain');
    expect(mimeTypeOfName('Nothing'), 'application/octet-stream');
    expect(mimeTypeOfName('Odd.xyz'), 'application/octet-stream');
  });
}
