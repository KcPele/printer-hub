import 'package:api_client/api_client.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/catalogue/catalogue.dart';
import 'package:printerhub/printers/printers.dart';
import 'package:printers_repository/printers_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend();
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  CatalogueCubit build() =>
      CatalogueCubit(printersRepository: backend.printers);

  List<String> names(CatalogueState state) => [
    for (final family in state.visible) family.manufacturer,
  ];

  test('starts out loading, showing everything', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, const CatalogueState());
    expect(cubit.state.filter, CatalogueFilter.all);
    expect(cubit.state.visible, isEmpty);
  });

  blocTest<CatalogueCubit, CatalogueState>(
    'lists the families',
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<CatalogueState>()
          .having((s) => s.status, 'status', CatalogueStatus.ready)
          .having(names, 'families', ['Xerox', 'HP', 'Brother']),
    ],
  );

  blocTest<CatalogueCubit, CatalogueState>(
    'says why the catalogue could not be read',
    setUp: () => backend.offline = true,
    build: build,
    act: (cubit) => cubit.load(),
    skip: 1,
    expect: () => [
      isA<CatalogueState>()
          .having((s) => s.status, 'status', CatalogueStatus.failed)
          .having((s) => s.error, 'error', isA<ApiUnreachable>()),
    ],
  );

  blocTest<CatalogueCubit, CatalogueState>(
    'narrows to what was typed, and to home or office',
    build: build,
    act: (cubit) async {
      await cubit.load();
      cubit
        ..search(' laser ')
        ..search('')
        ..show(CatalogueFilter.home)
        ..show(CatalogueFilter.office)
        ..search('xerox');
    },
    skip: 2,
    expect: () => [
      isA<CatalogueState>().having(names, 'laser', ['Brother']),
      isA<CatalogueState>().having(names, 'all', ['Xerox', 'HP', 'Brother']),
      isA<CatalogueState>().having(names, 'home', ['HP']),
      isA<CatalogueState>().having(names, 'office', ['Xerox', 'Brother']),
      isA<CatalogueState>()
          .having(names, 'office xerox', ['Xerox'])
          .having((s) => s.query, 'query', 'xerox')
          .having((s) => s.filter, 'filter', CatalogueFilter.office),
    ],
  );

  blocTest<CatalogueCubit, CatalogueState>(
    'keeps the search when the catalogue is read again',
    build: build,
    act: (cubit) async {
      cubit
        ..search('hp')
        ..show(CatalogueFilter.home);
      await cubit.load();
      backend.offline = true;
      await cubit.load();
    },
    // Searching and filtering, then the first read. Starting to read
    // changes nothing while there is nothing to show yet.
    skip: 2,
    expect: () => [
      isA<CatalogueState>().having(names, 'families', ['HP']),
      isA<CatalogueState>().having(
        (s) => s.status,
        'status',
        CatalogueStatus.loading,
      ),
      // Read once, so it is still there without the network.
      isA<CatalogueState>()
          .having(names, 'kept', ['HP'])
          .having((s) => s.query, 'query', 'hp'),
    ],
  );

  group('PrinterFamilyCubit', () {
    PrinterFamilyCubit family() =>
        PrinterFamilyCubit(printersRepository: backend.printers);

    blocTest<PrinterFamilyCubit, PrinterFamily?>(
      'finds the family of a printer',
      build: family,
      act: (cubit) => cubit.load(manufacturer: 'Xerox', model: 'C7130'),
      expect: () => [
        isA<PrinterFamily>().having((f) => f.name, 'name', contains('C7100')),
      ],
    );

    blocTest<PrinterFamilyCubit, PrinterFamily?>(
      'has none for a printer the catalogue does not know',
      build: family,
      act: (cubit) => cubit.load(manufacturer: 'Acme', model: 'Inkwell'),
      expect: () => <PrinterFamily?>[],
    );

    test('says nothing once the screen has gone', () async {
      final cubit = family();
      final loading = cubit.load(manufacturer: 'Xerox', model: 'C7130');
      await cubit.close();

      await loading;

      expect(cubit.state, isNull);
    });
  });
}
