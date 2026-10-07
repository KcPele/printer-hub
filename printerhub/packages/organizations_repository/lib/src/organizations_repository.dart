import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:local_store/local_store.dart';
import 'package:organizations_repository/src/organization.dart';

/// Lists and creates workspaces.
///
/// The list is kept on the device, so the app knows its workspace when it
/// starts offline.
class OrganizationsRepository {
  new({required this._client, required this._store});

  static const String _cacheKey = 'organizations.list';

  final PrinterHubClient _client;
  final SecureStore _store;

  /// The workspaces the user belongs to.
  ///
  /// When the API cannot be reached, answers with the list from the last
  /// time it could. Throws an [ApiException] when there is no such list, or
  /// when the API refuses.
  Future<List<Organization>> list() async {
    try {
      final organizations = await apiCall(
        () => _client.api.organizations.listOrganizations(),
      );
      final list = organizations.map(Organization.fromApi).toList();
      await _keep(list);
      return list;
    } on ApiUnreachable {
      final kept = await this.kept();
      if (kept == null) rethrow;
      return kept;
    }
  }

  /// Creates a workspace owned by the user.
  Future<Organization> create(String name) async {
    final created = Organization.fromApi(
      await apiCall(
        () => _client.api.organizations.createOrganization(
          body: OrganizationCreate(name: name),
        ),
      ),
    );
    await _keep([...?await kept(), created]);
    return created;
  }

  /// Forgets the kept list. Call when the user signs out.
  Future<void> clear() => _store.delete(_cacheKey);

  Future<void> _keep(List<Organization> organizations) {
    return _store.write(
      _cacheKey,
      jsonEncode([for (final item in organizations) item.toJson()]),
    );
  }

  /// The list from the last time the API was reached, without using the
  /// network. Null when there is none.
  Future<List<Organization>?> kept() async {
    final json = await _store.read(_cacheKey);
    if (json == null) return null;
    try {
      return [
        for (final item in jsonDecode(json) as List<dynamic>)
          Organization.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      // Written by an older version of the app.
      return null;
    }
  }
}
