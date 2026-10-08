import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobs_repository/jobs_repository.dart';

const _org = 'org-1';
const _presets = '/api/v1/organizations/$_org/presets';

void main() {
  late FakeApi api;
  late PresetsRepository repository;

  Map<String, dynamic> bodyOf(RequestOptions request) {
    return jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>;
  }

  setUp(() {
    api = FakeApi((request) async {
      if (request.method == 'DELETE') return const FakeResponse(204);
      if (request.method == 'GET' && request.path == _presets) {
        return FakeResponse(200, [
          presetBody(isDefault: true, copies: 2),
          presetBody(id: 'preset-2', name: 'Letterhead', scope: 'organization'),
          {
            ...presetBody(id: 'preset-3', name: 'Receipts'),
            'type': 'scan',
            'settings': {
              'source': 'auto',
              'duplex': false,
              'color_mode': 'auto',
              'resolution_dpi': 300,
              'format': 'application/pdf',
              'media_size': null,
              'searchable_pdf': false,
            },
          },
        ]);
      }
      return FakeResponse(
        request.method == 'POST' ? 201 : 200,
        presetBody(printerId: 'printer-1'),
      );
    });
    final client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: InMemoryTokenStore(),
      httpClientAdapter: api,
    );
    addTearDown(client.close);
    repository = PresetsRepository(client: client);
  });

  test('lists the presets that can be used on a printer', () async {
    final presets = await repository.list(
      organizationId: _org,
      printerId: 'printer-1',
    );

    final request = api.requests.single;
    expect(request.path, _presets);
    expect(request.queryParameters, {
      'type': 'print',
      'printer_id': 'printer-1',
    });
    expect(presets, hasLength(3));
    expect(presets.first.name, 'Handouts');
    expect(presets.first.isDefault, isTrue);
    expect(presets.first.shared, isFalse);
    expect(presets.first.print!.copies, 2);
    expect(presets.first.print!.twoSided, isTrue);
    expect(presets[1].shared, isTrue);
    // A scan preset has nothing to say about printing.
    expect(presets[2].kind, 'scan');
    expect(presets[2].print, isNull);
  });

  test('lists presets of another kind, for any printer', () async {
    await repository.list(organizationId: _org, kind: 'scan');

    expect(api.requests.single.queryParameters, {'type': 'scan'});
  });

  test('reads one preset as it is now', () async {
    final preset = await repository.get(
      organizationId: _org,
      presetId: 'preset-1',
    );

    expect(api.requests.single.path, '$_presets/preset-1');
    expect(preset.printerId, 'printer-1');
    expect(
      preset,
      Preset.fromApi(
        PresetRead.fromJson(presetBody(printerId: 'printer-1').cast()),
      ),
    );
  });

  test('saves how to print, without the pages of one document', () async {
    await repository.savePrint(
      organizationId: _org,
      name: 'Handouts',
      choices: const PrintChoices(copies: 4, pageRanges: '1-2', tray: 'tray-2'),
      printerId: 'printer-1',
      isDefault: true,
    );

    final request = api.requests.single;
    final sent = bodyOf(request);
    expect(request.method, 'POST');
    expect(request.path, _presets);
    expect(sent['type'], 'print');
    expect(sent['name'], 'Handouts');
    expect(sent['scope'], 'personal');
    expect(sent['printer_id'], 'printer-1');
    expect(sent['is_default'], isTrue);
    expect(sent['settings'], containsPair('copies', 4));
    expect(sent['settings'], containsPair('tray', 'tray-2'));
    expect((sent['settings'] as Map)['page_ranges'], isNull);
  });

  test('saves a preset for the whole workspace', () async {
    await repository.savePrint(
      organizationId: _org,
      name: 'Letterhead',
      choices: const PrintChoices(),
      shared: true,
    );

    final sent = bodyOf(api.requests.single);
    expect(sent['scope'], 'organization');
    expect(sent['printer_id'], isNull);
    expect(sent['is_default'], isFalse);
  });

  test('changes only what it is given', () async {
    await repository.update(
      organizationId: _org,
      presetId: 'preset-1',
      name: 'Drafts',
    );
    await repository.update(
      organizationId: _org,
      presetId: 'preset-1',
      choices: const PrintChoices(copies: 2, pageRanges: '3'),
      isDefault: true,
    );

    final renamed = bodyOf(api.requests.first);
    final changed = bodyOf(api.requests.last);
    expect(api.requests.first.method, 'PATCH');
    expect(api.requests.first.path, '$_presets/preset-1');
    expect(renamed['name'], 'Drafts');
    expect(renamed['settings'], isNull);
    expect(renamed['is_default'], isNull);
    expect(changed['name'], isNull);
    expect(changed['is_default'], isTrue);
    expect(changed['settings'], containsPair('copies', 2));
    expect((changed['settings'] as Map)['page_ranges'], isNull);
  });

  test('deletes a preset', () async {
    await repository.delete(organizationId: _org, presetId: 'preset-1');

    expect(api.requests.single.method, 'DELETE');
    expect(api.requests.single.path, '$_presets/preset-1');
  });
}
