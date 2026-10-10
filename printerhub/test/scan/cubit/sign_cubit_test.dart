import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:local_store/local_store.dart';
import 'package:printerhub/scan/scan.dart';

void main() {
  late InMemorySecureStore values;
  late SignatureStore store;

  setUp(() {
    values = InMemorySecureStore();
    store = SignatureStore(store: values);
  });

  SignCubit build({int pages = 3, PlacedSignature? placed}) {
    final cubit = SignCubit(
      store: store,
      pages: pages,
      // A4, upright.
      sheetAspect: 210 / 297,
      placed: placed,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Uint8List kept({int width = 60, int height = 20}) =>
      img.encodePng(img.Image(width: width, height: height));

  test('starts on the last sheet, waiting to hear of a kept signature', () {
    final cubit = build();

    expect(cubit.state.loading, isTrue);
    expect(cubit.state.page, 2);
    expect(cubit.placed, isNull);
  });

  test('with none kept, opens the pad', () async {
    final cubit = build();

    await cubit.load();

    expect(cubit.state.loading, isFalse);
    expect(cubit.state.signature, isNull);
  });

  test('with one kept, is ready to place it', () async {
    await store.save(kept());
    final cubit = build();

    await cubit.load();

    expect(cubit.state.signature, isNotNull);
    expect(cubit.state.aspect, 3);
    expect(cubit.placed!.page, 2);
  });

  test('treats a kept signature it cannot read as none', () async {
    await store.save(Uint8List.fromList([1, 2, 3]));
    final cubit = build();

    await cubit.load();

    expect(cubit.state.signature, isNull);
    expect(cubit.state.loading, isFalse);
  });

  test('draws lines on the pad, wipes them, and takes them as the '
      'signature', () async {
    final cubit = build();
    await cubit.load();
    // A line cannot be carried on before one is begun.
    cubit.drawTo(const Point(5, 5));
    expect(cubit.state.drawn, isFalse);

    cubit
      ..begin(const Point(20, 20))
      ..drawTo(const Point(80, 40))
      ..begin(const Point(30, 60))
      ..drawTo(const Point(90, 70));
    expect(cubit.state.strokes, hasLength(2));
    expect(cubit.state.strokes.first, hasLength(2));
    expect(cubit.state.drawn, isTrue);

    cubit.wipe();
    expect(cubit.state.drawn, isFalse);
    await cubit.use(width: 300, height: 150);
    expect(cubit.state.signature, isNull);

    cubit
      ..begin(const Point(20, 20))
      ..drawTo(const Point(120, 50));
    await cubit.use(width: 300, height: 150);

    expect(cubit.state.signature, isNotNull);
    expect(cubit.state.strokes, isEmpty);
    // Kept on the phone for next time.
    expect(await store.read(), cubit.state.signature);
  });

  test('moves and sizes the signature, and keeps it whole on the '
      'sheet', () async {
    await store.save(kept());
    final cubit = build();
    await cubit.load();

    cubit.move(-5, -5);
    expect((cubit.state.x, cubit.state.y), (0, 0));

    cubit.move(5, 5);
    expect(cubit.state.x, closeTo(1 - cubit.state.width, 1e-9));
    // As tall as a third of its width, on a sheet taller than it is wide.
    final height = cubit.state.width / 3 * (210 / 297);
    expect(cubit.state.y, closeTo(1 - height, 1e-9));

    cubit.resize(5);
    expect(cubit.state.width, SignCubit.maxWidth);
    expect(cubit.state.x, closeTo(1 - SignCubit.maxWidth, 1e-9));
    cubit.resize(0);
    expect(cubit.state.width, SignCubit.minWidth);
  });

  test('never makes a tall signature taller than the sheet', () async {
    await store.save(kept(width: 10, height: 200));
    final cubit = build();
    await cubit.load();

    cubit.move(0, 5);

    expect(cubit.state.y, 0);
  });

  test('goes on the sheet asked for, among those there are', () async {
    await store.save(kept());
    final cubit = build();
    await cubit.load();

    cubit.onPage(0);
    expect(cubit.placed!.page, 0);
    cubit.onPage(9);
    expect(cubit.placed!.page, 2);
  });

  test('begins from where a signature already is', () async {
    await store.save(kept());
    final cubit = build(
      pages: 2,
      placed: PlacedSignature(
        png: kept(),
        // A sheet that has since been taken out.
        page: 5,
        x: 0.1,
        y: 0.2,
        width: 0.4,
      ),
    );
    await cubit.load();

    expect(cubit.state.page, 1);
    expect((cubit.state.x, cubit.state.y, cubit.state.width), (0.1, 0.2, 0.4));
  });

  test('forgets the kept signature to draw another', () async {
    await store.save(kept());
    final cubit = build();
    await cubit.load();

    await cubit.redraw();

    expect(cubit.state.signature, isNull);
    expect(await store.read(), isNull);
  });

  test('says nothing once the screen has gone', () async {
    await store.save(kept());
    final loading = build();
    final load = loading.load();
    await loading.close();
    await load;

    final using = build();
    await using.load();
    await using.redraw();
    using
      ..begin(const Point(20, 20))
      ..drawTo(const Point(120, 50));
    final use = using.use(width: 300, height: 150);
    await using.close();
    await use;

    await store.save(kept());
    final redrawing = build();
    await redrawing.load();
    final redraw = redrawing.redraw();
    await redrawing.close();
    await redraw;
  });
}
