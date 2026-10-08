import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:printerhub/print/print.dart';

import '../../helpers/helpers.dart';

const _org = '0198c0de-0000-7000-8000-00000000000b';
const _presets = '/organizations/$_org/presets';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend()
      ..presetList = [
        presetBody(),
        presetBody(id: 'preset-2', name: 'Letterhead', scope: 'organization'),
      ];
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  PresetsCubit build() => PresetsCubit(
    presetsRepository: backend.presets,
    organizationId: _org,
    printerId: 'printer-1',
  );

  Future<PresetsCubit> loaded() async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  List<String> names(PresetsState state) => [
    for (final preset in state.presets) preset.name,
  ];

  test('starts with nothing read', () {
    final cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state, const PresetsState());
    expect(cubit.standard, isNull);
  });

  group('load', () {
    blocTest<PresetsCubit, PresetsState>(
      'lists the ways of printing saved for this printer, by name',
      setUp: () => backend.presetList = [
        ...backend.presetList,
        {
          ...presetBody(id: 'preset-3', name: 'Receipts'),
          'type': 'scan',
          'settings': jobBody(type: 'scan')['settings'],
        },
      ],
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<PresetsState>().having((s) => s.loaded, 'loaded', isTrue).having(
          names,
          'names',
          ['Handouts', 'Letterhead'],
        ),
      ],
      verify: (_) => expect(
        backend.sent('GET $_presets').single.queryParameters,
        {'type': 'print', 'printer_id': 'printer-1'},
      ),
    );

    blocTest<PresetsCubit, PresetsState>(
      'does without them when they cannot be read',
      setUp: () => backend.offline = true,
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const PresetsState(loaded: true)],
    );

    test('says nothing once the screen has gone', () async {
      final cubit = build();
      final loading = cubit.load();
      await cubit.close();
      await loading;

      backend.offline = true;
      final again = build();
      final failing = again.load();
      await again.close();
      await expectLater(failing, completes);
    });
  });

  group('what a print starts from', () {
    test('is nothing when no preset is marked', () async {
      expect((await loaded()).standard, isNull);
    });

    test('is the person’s own before the workspace’s, and one for this '
        'printer before one for any', () async {
      backend.presetList = [
        presetBody(id: 'a', name: 'A', scope: 'organization', isDefault: true),
        presetBody(
          id: 'b',
          name: 'B',
          scope: 'organization',
          printerId: 'printer-1',
          isDefault: true,
        ),
        presetBody(id: 'c', name: 'C', isDefault: true),
        presetBody(id: 'd', name: 'D', printerId: 'printer-1', isDefault: true),
      ];
      final cubit = await loaded();
      expect(cubit.standard!.name, 'D');

      backend.presetList = backend.presetList.sublist(0, 3);
      await cubit.load();
      expect(cubit.standard!.name, 'C');

      backend.presetList = backend.presetList.sublist(0, 2);
      await cubit.load();
      expect(cubit.standard!.name, 'B');

      backend.presetList = backend.presetList.sublist(0, 1);
      await cubit.load();
      expect(cubit.standard!.name, 'A');
    });
  });

  group('fresh', () {
    test('reads a preset as it is now', () async {
      final cubit = await loaded();
      backend.presetList = [presetBody(copies: 7), backend.presetList.last];

      final fresh = await cubit.fresh(cubit.state.presets.first);

      expect(fresh!.print!.copies, 7);
    });

    test('uses the one listed while the API is out of reach', () async {
      final cubit = await loaded();
      backend.offline = true;

      final listed = cubit.state.presets.first;
      expect(await cubit.fresh(listed), listed);
    });

    test('drops one that has been deleted', () async {
      final cubit = await loaded();
      final listed = cubit.state.presets.first;
      backend.presetList = [backend.presetList.last];

      expect(await cubit.fresh(listed), isNull);
      expect(names(cubit.state), ['Letterhead']);
    });
  });

  group('changes', () {
    blocTest<PresetsCubit, PresetsState>(
      'saves the choices under a name, for this printer',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.save(
          name: 'Drafts',
          choices: const PrintChoices(copies: 3, quality: 'draft'),
          isDefault: true,
        );
      },
      skip: 1,
      expect: () => [
        isA<PresetsState>().having((s) => s.busy, 'busy', isTrue),
        isA<PresetsState>().having((s) => s.busy, 'busy', isFalse).having(
          names,
          'names',
          ['Drafts', 'Handouts', 'Letterhead'],
        ),
      ],
      verify: (cubit) {
        final saved = backend.presetList.last;
        expect(saved['printer_id'], 'printer-1');
        expect(saved['scope'], 'personal');
        expect(saved['is_default'], isTrue);
        expect((saved['settings']! as Map)['copies'], 3);
        expect(cubit.standard!.name, 'Drafts');
      },
    );

    test('shares a preset with the workspace', () async {
      final cubit = await loaded();

      await cubit.save(
        name: 'Everyone',
        choices: const PrintChoices(),
        shared: true,
      );

      expect(backend.presetList.last['scope'], 'organization');
      expect(cubit.state.presets.first.shared, isTrue);
    });

    test('renames a preset', () async {
      final cubit = await loaded();

      await cubit.rename(cubit.state.presets.first, 'Minutes');

      expect(names(cubit.state), ['Letterhead', 'Minutes']);
    });

    test('makes a preset what a print starts from, and stops it', () async {
      final cubit = await loaded();

      await cubit.setStandard(cubit.state.presets.first, standard: true);
      expect(cubit.standard!.name, 'Handouts');

      // A new one takes the place of the old.
      await cubit.setStandard(cubit.state.presets.last, standard: true);
      expect(cubit.standard!.name, 'Letterhead');
      expect(cubit.state.presets.first.isDefault, isFalse);

      await cubit.setStandard(cubit.state.presets.last, standard: false);
      expect(cubit.standard, isNull);
    });

    test('puts the choices made now in place of a preset’s', () async {
      final cubit = await loaded();

      await cubit.replace(
        cubit.state.presets.first,
        const PrintChoices(copies: 9),
      );

      expect(cubit.state.presets.first.print!.copies, 9);
      expect(cubit.state.presets.first.print!.twoSided, isFalse);
    });

    test('deletes a preset', () async {
      final cubit = await loaded();

      await cubit.remove(cubit.state.presets.first);

      expect(names(cubit.state), ['Letterhead']);
    });

    blocTest<PresetsCubit, PresetsState>(
      'says why a change could not be made, and keeps the list',
      build: build,
      act: (cubit) async {
        await cubit.load();
        backend.fail('DELETE $_presets/preset-2', 403, 'permission.denied');
        await cubit.remove(cubit.state.presets.last);
      },
      skip: 2,
      expect: () => [
        isA<PresetsState>()
            .having((s) => s.error, 'error', isA<ApiProblem>())
            .having((s) => s.busy, 'busy', isFalse)
            .having(names, 'names', ['Handouts', 'Letterhead']),
      ],
    );

    test('makes one change at a time', () async {
      final cubit = await loaded();
      backend.network.requests.clear();

      final first = cubit.rename(cubit.state.presets.first, 'One');
      await cubit.rename(cubit.state.presets.first, 'Two');
      await first;

      expect(backend.sent('PATCH $_presets/preset-1'), hasLength(1));
      expect(names(cubit.state), ['Letterhead', 'One']);
    });
  });
}
