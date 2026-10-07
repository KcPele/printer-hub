import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store/local_store.dart';
import 'package:organizations_repository/organizations_repository.dart';

Map<String, Object?> _organization(String id, String name, String role) {
  return organizationBody(id: id, name: name, role: role);
}

void main() {
  late InMemorySecureStore store;
  late FakeApi network;
  late OrganizationsRepository repository;

  setUp(() {
    store = InMemorySecureStore();
    network = FakeApi(
      (_) async => FakeResponse(200, [
        _organization('1', 'Acme', 'owner'),
        _organization('2', 'Globex', 'user'),
      ]),
    );
    final client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: InMemoryTokenStore(),
      httpClientAdapter: network,
    );
    addTearDown(client.close);
    repository = OrganizationsRepository(client: client, store: store);
  });

  group('list', () {
    test('returns the workspaces the user belongs to', () async {
      final organizations = await repository.list();

      expect(organizations, const [
        Organization(id: '1', name: 'Acme', role: 'owner'),
        Organization(id: '2', name: 'Globex', role: 'user'),
      ]);
      expect(organizations.first.canManage, isTrue);
      expect(organizations.last.canManage, isFalse);
    });

    test('answers from the last list when offline', () async {
      final online = await repository.list();
      network.handler = (_) async => throw const FormatException('offline');

      expect(await repository.list(), online);
    });

    test('fails offline when there is no earlier list', () async {
      network.handler = (_) async => throw const FormatException('offline');

      await expectLater(repository.list(), throwsA(isA<ApiUnreachable>()));
    });

    test('fails offline when the kept list cannot be read', () async {
      await store.write('organizations.list', '{"not":"a list"}');
      network.handler = (_) async => throw const FormatException('offline');

      await expectLater(repository.list(), throwsA(isA<ApiUnreachable>()));
    });

    test('reports a refusal from the API', () async {
      network.handler = (_) async =>
          FakeResponse.problem(401, 'auth.unauthorized');

      await expectLater(repository.list(), throwsA(isA<ApiProblem>()));
    });
  });

  group('create', () {
    Future<FakeResponse> creating(RequestOptions request) async {
      if (request.method == 'POST') {
        final name = (request.data as Map<String, dynamic>)['name'] as String;
        return FakeResponse(201, _organization('3', name, 'owner'));
      }
      throw const FormatException('offline');
    }

    test('creates a workspace owned by the user', () async {
      network.handler = creating;

      final created = await repository.create('Initech');

      expect(
        created,
        const Organization(id: '3', name: 'Initech', role: 'owner'),
      );
    });

    test('adds it to the kept list', () async {
      await repository.list();
      network.handler = creating;

      await repository.create('Initech');

      expect((await repository.list()).map((item) => item.name), [
        'Acme',
        'Globex',
        'Initech',
      ]);
    });
  });

  test('kept answers without the network', () async {
    expect(await repository.kept(), isNull);

    final online = await repository.list();
    network.requests.clear();

    expect(await repository.kept(), online);
    expect(network.requests, isEmpty);
  });

  test('clear forgets the kept list', () async {
    await repository.list();
    network.handler = (_) async => throw const FormatException('offline');

    await repository.clear();

    await expectLater(repository.list(), throwsA(isA<ApiUnreachable>()));
  });

  test('treats an unknown role as the most limited one', () {
    final organization = Organization.fromApi(
      OrganizationRead.fromJson(_organization('1', 'Acme', 'auditor').cast()),
    );

    expect(organization.role, 'viewer');
  });
}
