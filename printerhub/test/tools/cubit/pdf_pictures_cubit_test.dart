import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/tools/tools.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() {
    backend = TestBackend();
    backend.picker.next = pickedPdfFile(backend.scans);
  });
  tearDown(() => backend.close());

  PdfPicturesCubit build({bool long = false}) {
    final cubit = PdfPicturesCubit(
      picker: backend.picker,
      renderer: backend.renderer,
      sharer: backend.sharer,
      long: long,
      directory: backend.scans,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  List<String> names(ToolState state) => [
    for (final file in state.files) file.uri.pathSegments.last,
  ];

  test('makes a picture of each page', () async {
    final cubit = build();

    await cubit.choose();

    expect(cubit.state.status, ToolStatus.done);
    expect(cubit.state.name, 'Report');
    expect(names(cubit.state), ['Report 1.jpg', 'Report 2.jpg']);
  });

  test('makes one tall picture of every page', () async {
    final cubit = build(long: true);

    await cubit.choose();

    expect(names(cubit.state), ['Report.jpg']);
  });

  test('will not join more pages than a picture can hold', () async {
    backend.renderer.pageCount = maxLongPicturePages + 1;
    final cubit = build(long: true);

    await cubit.choose();

    expect(cubit.state.status, ToolStatus.idle);
    expect(cubit.state.failure, 'tools.too_long');

    // The same PDF is fine as a picture a page.
    final pages = build();
    await pages.choose();
    expect(pages.state.files, hasLength(maxLongPicturePages + 1));
  });

  test('says when the PDF cannot be read', () async {
    backend.renderer.unreadable = true;
    final cubit = build();

    await cubit.choose();

    expect(cubit.state.failure, 'tools.unreadable');
  });

  test('changes nothing when no file is chosen, and takes one at a '
      'time', () async {
    backend.picker.next = null;
    final cubit = build();
    await cubit.choose();
    expect(cubit.state, const ToolState());

    backend.picker.next = pickedPdfFile(backend.scans);
    final first = cubit.choose();
    await cubit.choose();
    await first;
    // Once for nothing, once for the PDF, and not a third time.
    expect(backend.picker.opened, 2);
  });

  test('says nothing once the screen has gone', () async {
    for (final setUp in <void Function()>[
      () {},
      () => backend.renderer.unreadable = true,
      () => backend.renderer
        ..unreadable = false
        ..pageCount = maxLongPicturePages + 1,
    ]) {
      setUp();
      final cubit = build(long: true);
      final making = cubit.choose();
      await pumpEventQueue(times: 2);
      await cubit.close();
      await making;
      expect(cubit.state.files, isEmpty);
    }

    final unchosen = build();
    final choosing = unchosen.choose();
    await unchosen.close();
    await choosing;
  });

  test('shares the pictures', () async {
    final cubit = build();
    await cubit.share();
    expect(backend.sharer.shared, isEmpty);

    await cubit.choose();
    await cubit.share();

    expect(backend.sharer.shared.single.files, hasLength(2));
    expect(backend.sharer.shared.single.name, 'Report');
  });
}
