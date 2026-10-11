import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/documents/documents.dart';

void main() {
  test('knows what kind of file it is from its name', () {
    expect(OpenDocumentButton.mimeTypeOf('Scan.pdf'), 'application/pdf');
    expect(OpenDocumentButton.mimeTypeOf('Photo.JPG'), 'image/jpeg');
    expect(OpenDocumentButton.mimeTypeOf('Photo.jpeg'), 'image/jpeg');
    expect(OpenDocumentButton.mimeTypeOf('Page.png'), 'image/png');
    expect(OpenDocumentButton.mimeTypeOf('Words.txt'), 'text/plain');
    expect(
      OpenDocumentButton.mimeTypeOf('Nothing'),
      'application/octet-stream',
    );
    expect(
      OpenDocumentButton.mimeTypeOf('Odd.xyz'),
      'application/octet-stream',
    );
  });
}
