import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/tools/tools.dart';

class _NoAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw StateError('no $key');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads the font that ships with the app', () async {
    final font = await pdfFont();

    expect(font, isNotNull);
    expect(font!.lengthInBytes, greaterThan(1000));
  });

  test('is nothing when the font cannot be read', () async {
    expect(await pdfFont(_NoAssets()), isNull);
  });
}
