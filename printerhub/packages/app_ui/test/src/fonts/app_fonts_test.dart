import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBundle extends CachingAssetBundle {
  new(this.files);

  final Map<String, ByteData> files;
  final List<String> loaded = [];

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{
        for (final file in files.keys)
          file: <Object>[
            <String, Object>{'asset': file},
          ],
      })!;
    }
    loaded.add(key);
    return files[key]!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fonts are registered for the whole test run, and every test shares one
  // process. Bytes that are not a font register nothing, so Volt's text in
  // the golden tests is not redrawn by this test. What is checked here is
  // which files are picked up.
  final font = ByteData.sublistView(Uint8List.fromList([0, 1, 2, 3]));
  final text = ByteData(0);

  group('AppFonts.loadLicensed', () {
    test('loads nothing on a checkout without the licensed files', () async {
      final bundle = _FakeBundle({
        'packages/app_ui/assets/fonts/lufga/README.md': text,
        'packages/app_ui/assets/illustrations/printer.svg': text,
      });

      expect(await AppFonts.loadLicensed(bundle: bundle), 0);
      expect(bundle.loaded, isEmpty);
    });

    test('registers every font file in the Lufga folder', () async {
      const regular = 'packages/app_ui/assets/fonts/lufga/Lufga-Regular.ttf';
      const bold = 'packages/app_ui/assets/fonts/lufga/Lufga-Bold.OTF';
      final bundle = _FakeBundle({
        regular: font,
        bold: font,
        'packages/app_ui/assets/fonts/lufga/README.md': text,
        'packages/other/assets/fonts/Other.ttf': font,
      });

      expect(await AppFonts.loadLicensed(bundle: bundle), 2);
      expect(bundle.loaded, unorderedEquals([regular, bold]));
    });

    test('reads the app bundle by default', () async {
      expect(await AppFonts.loadLicensed(), 0);
    });
  });
}
