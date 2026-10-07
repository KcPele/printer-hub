# api_client

The PrinterHub API for Dart, generated from `backend/openapi.json`. Pure Dart: no Flutter, so it runs in plain unit tests.

```dart
final client = PrinterHubClient(
  baseUrl: Uri.parse('https://printerhub-backend.kcpele.com'),
  tokenStore: tokenStore,
);

final session = await apiCall(
  () => client.api.auth.login(body: LoginRequest(email: email, password: password)),
);
await client.startSession(session.tokens);

final printers = await apiCall(() => client.api.printers.listPrinters(orgId: orgId));
```

## What is generated and what is written

| Path | Source |
|---|---|
| `lib/src/generated/` | `swagger_parser` and `build_runner`. **Never edit.** Run `make openapi` |
| `lib/src/*.dart` | Written by hand: sessions, errors, idempotency keys |

When a generated type is wrong, fix the backend schema and regenerate.

## Sessions

`PrinterHubClient` sends the access token with every request. When it expires, the refresh token is exchanged for a new pair and the request is repeated, once. Requests that expire together share one refresh, because the API revokes a session whose refresh token is used twice.

When the session cannot be renewed, the tokens are cleared and `sessionEnded` fires.

Tokens are kept in a `TokenStore`. The app supplies one backed by the platform keystore.

## Errors

Wrap a call in `apiCall`. It throws one of two things:

- `ApiProblem`: the API answered with an error. Branch on `code` (`auth.invalid_credentials`); `detail` is for people; `fieldErrors` lists rejected fields.
- `ApiUnreachable`: no answer. Offline, a timeout, or an unreadable reply.

## Idempotency

Creating or retrying a job needs an `Idempotency-Key`. Make one with `newIdempotencyKey()`, save it with the job before the first attempt, and reuse it on every retry.

## Regenerating

```sh
make openapi       # the contract, the TypeScript types, and this client
make dart-client   # this client only
```

CI fails when the checked-in client does not match the contract.

`build.yaml` sets `field_rename: snake`, which the variants of a union (`JobRead`, `PresetRead`) need to read the API's field names. `test/src/contract_test.dart` decodes each variant from a sample written by `tool/make_fixtures.py`.
