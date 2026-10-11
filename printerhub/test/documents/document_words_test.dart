import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/documents/documents.dart';
import 'package:printerhub/l10n/l10n.dart';

import '../helpers/helpers.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  StoredDocument document({
    String mimeType = 'application/pdf',
    int? pageCount = 3,
    int sizeBytes = 2048,
  }) {
    return StoredDocument.fromApi(
      DocumentRead.fromJson(
        documentBody(
          mimeType: mimeType,
          pageCount: pageCount,
          sizeBytes: sizeBytes,
        ).cast(),
      ),
    );
  }

  test('what made a document is said by name', () {
    final said = {
      for (final source in DocumentSources.all)
        source: DocumentWords.source(l10n, source),
    };
    // Each has words of its own.
    expect(said.values.toSet(), hasLength(DocumentSources.all.length));
    expect(said[DocumentSources.printerScan], 'Scanned on a printer');
    expect(said[DocumentSources.pdfPictures], 'PDF to pictures');
    expect(said[DocumentSources.upload], 'Other');
    // One the app has not heard of is no worse than that.
    expect(DocumentWords.source(l10n, 'something_new'), 'Other');
  });

  test('how far back a list goes is said in words', () {
    expect(
      [for (final age in DocumentsAge.values) DocumentWords.age(l10n, age)],
      ['Any time', 'Today', 'Last 7 days', 'Last 30 days'],
    );
  });

  test('a kind of file has its sign', () {
    expect(
      DocumentWords.iconOf('application/pdf'),
      Icons.picture_as_pdf_outlined,
    );
    expect(DocumentWords.iconOf('image/png'), Icons.image_outlined);
    expect(DocumentWords.iconOf('text/plain'), Icons.description_outlined);
  });

  test('a size is said the way people say it', () {
    expect(DocumentWords.size(l10n, 1), '1 KB');
    expect(DocumentWords.size(l10n, 1024), '1 KB');
    expect(DocumentWords.size(l10n, 28 * 1024 + 1), '29 KB');
    expect(DocumentWords.size(l10n, 1024 * 1024), '1.0 MB');
    expect(DocumentWords.size(l10n, 1500 * 1024), '1.5 MB');
  });

  test('a document has the picture of what it is', () {
    expect(DocumentWords.icon(document()), Icons.picture_as_pdf_outlined);
    expect(
      DocumentWords.icon(document(mimeType: 'image/jpeg')),
      Icons.image_outlined,
    );
    expect(
      DocumentWords.icon(document(mimeType: 'text/plain')),
      Icons.description_outlined,
    );
  });

  testWidgets('a document is summed up in a line', (tester) async {
    late String withPages;
    late String without;
    await tester.pumpApp(
      Builder(
        builder: (context) {
          withPages = DocumentWords.detail(context, document());
          without = DocumentWords.detail(
            context,
            document(pageCount: null, sizeBytes: 3 * 1024 * 1024),
          );
          return const SizedBox();
        },
      ),
    );

    expect(withPages, startsWith('3 pages · 2 KB · '));
    expect(withPages, contains('Oct 7'));
    expect(without, startsWith('3.0 MB · '));
  });
}
