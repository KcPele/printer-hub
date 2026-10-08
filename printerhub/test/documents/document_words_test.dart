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
