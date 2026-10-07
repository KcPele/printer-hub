# @printerhub/api-client

The typed client for the PrinterHub API. The mobile and web apps import it instead of writing request code by hand.

Every path, parameter, request body, and response is checked by TypeScript against `src/schema.d.ts`, which is generated from `backend/openapi.json`. A request the backend would reject for its shape does not compile.

## Use

```ts
import { createPrinterHubClient, newIdempotencyKey, unwrap } from "@printerhub/api-client";

const api = createPrinterHubClient({
  baseUrl: "https://printerhub-backend.kcpele.com",
  getAccessToken: () => session.accessToken,
  refreshAccessToken: async () => {
    const { data } = await api.POST("/api/v1/auth/refresh", {
      body: { refresh_token: session.refreshToken },
    });
    if (!data) return null;
    session.save(data); // store both new tokens
    return data.access_token;
  },
  onSignedOut: () => session.clear(),
});
```

Each call returns `{ data, error, response }`. Exactly one of `data` and `error` is set:

```ts
const { data, error } = await api.GET("/api/v1/organizations/{org_id}/printers", {
  params: { path: { org_id }, query: { limit: 20 } },
});
if (error) {
  showMessage(error.detail); // error.code is the stable identifier to branch on
}
```

`unwrap` turns that into a value or a thrown `ProblemError`, which suits TanStack Query:

```ts
const me = unwrap(await api.GET("/api/v1/users/me"));
```

## What the client does for you

- **Sends the access token** on every request.
- **Refreshes an expired token once and repeats the request.** When several requests fail at the same moment they share one refresh. This matters: the API revokes a session whose refresh token is used twice.
- **Calls `onSignedOut`** when the session cannot be recovered, so the app can return to the sign-in screen.

It stores nothing. Keeping tokens in secure storage is the app's job (FR-MOB-018).

## Rules for callers

- **Send a fresh `Idempotency-Key` per job, and reuse it on every retry of that request.** `newIdempotencyKey()` makes one. Persist it with the queued job so a retry after an app restart still uses the same key. On React Native, install a `crypto.randomUUID` polyfill such as `expo-crypto`.
- **Branch on `error.code`, never on `error.detail`.** Codes such as `job.invalid_transition` are part of the contract. The detail text is for people and may change.
- **Fields with defaults are optional when sending and always present when reading.** `settings: { copies: 2 }` is a complete print request; the response carries every setting.

## When the API changes

From the repo root:

```bash
make openapi
```

That rewrites `backend/openapi.json` and `src/schema.d.ts` together. Commit both. Any app code the change breaks then fails to compile, which is the point.

`pnpm api:check` runs the type checks and tests. `test/types.ts` holds compile-time checks of the contract itself.

## Versions

TypeScript is pinned to 5.x here. `openapi-typescript` uses the TypeScript compiler's JavaScript API, which TypeScript 7 does not provide.
