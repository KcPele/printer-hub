// Calls a running backend through the generated client, end to end.
//
// It proves what unit tests cannot: that the client and the real API agree.
// Start the backend (`make dev`), then:  dart run tool/smoke.dart
//
// It registers a throwaway account on that backend, so point it at a
// development one only.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:api_client/api_client.dart';

Future<void> main(List<String> arguments) async {
  final baseUrl = Uri.parse(
    arguments.isEmpty ? 'http://localhost:8000' : arguments.first,
  );
  if (baseUrl.host != 'localhost' && baseUrl.host != '127.0.0.1') {
    stderr.writeln('Refusing to create test accounts on ${baseUrl.host}.');
    exit(64);
  }

  final store = InMemoryTokenStore();
  final client = PrinterHubClient(baseUrl: baseUrl, tokenStore: store);
  final api = client.api;
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final email = 'smoke-$stamp@example.com';
  final password = 'smoke-${newIdempotencyKey()}';

  Future<T> step<T>(String name, Future<T> Function() call) async {
    try {
      final result = await apiCall(call);
      print('ok    $name');
      return result;
    } on ApiException catch (error) {
      print('FAIL  $name: $error');
      exit(1);
    }
  }

  final registered = await step(
    'register',
    () => api.auth.register(
      body: RegisterRequest(
        name: 'Smoke Test',
        email: email,
        password: password,
      ),
    ),
  );
  await client.startSession(registered.tokens);

  final me = await step('read the account', () => api.users.getMe());
  if (me.email != email) throw StateError('Wrong account: ${me.email}');

  await step(
    'save the theme with the account',
    () => api.users.updateMe(
      body: const UserUpdate(
        preferences: UserPreferencesInput(
          appTheme: UserPreferencesInputAppTheme.indigo,
          mutedNotificationTypes: [],
        ),
      ),
    ),
  );

  final organization = await step(
    'create a workspace',
    () => api.organizations.createOrganization(
      body: const OrganizationCreate(name: 'Smoke workspace'),
    ),
  );
  final organizations = await step(
    'list workspaces',
    () => api.organizations.listOrganizations(),
  );
  if (!organizations.any((item) => item.id == organization.id)) {
    throw StateError('The new workspace is not in the list.');
  }

  await step(
    'list printers',
    () => api.printers.listPrinters(orgId: organization.id),
  );
  await step('list jobs', () => api.jobs.listJobs(orgId: organization.id));
  await step('list sessions', () => api.auth.listSessions());

  // An access token the API rejects as expired is renewed without the
  // caller noticing. Simulated by swapping in a malformed one is not the
  // same thing, so the refresh endpoint is called directly instead.
  final tokens = (await store.read())!;
  final renewed = await step(
    'renew the session',
    () => api.auth.refresh(
      body: RefreshRequest(refreshToken: tokens.refreshToken),
    ),
  );
  await client.startSession(renewed);
  await step('use the renewed session', () => api.users.getMe());

  try {
    await apiCall(
      () => api.auth.login(
        body: LoginRequest(email: email, password: 'not the password'),
      ),
    );
    print('FAIL  a wrong password was accepted');
    exit(1);
  } on ApiProblem catch (problem) {
    if (problem.code != 'auth.invalid_credentials') {
      print('FAIL  wrong password gave ${problem.code}');
      exit(1);
    }
    print('ok    a wrong password is refused with a typed error');
  }

  await step(
    'delete the account',
    () => api.account.deleteAccount(
      body: AccountDeleteRequest(password: password),
    ),
  );
  await client.close();
  print('\nThe client and the API agree.');
  exit(0);
}
