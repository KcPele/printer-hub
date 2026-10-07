import assert from "node:assert/strict";
import { test } from "node:test";

import {
  ProblemError,
  createPrinterHubClient,
  newIdempotencyKey,
  unwrap,
} from "../src/index.ts";

const BASE = "https://api.example.test";
const USER = {
  id: "0190a1b2-0000-7000-8000-000000000001",
  email: "ada@example.com",
  email_verified_at: null,
  name: "Ada",
  preferences: {
    theme: "system",
    default_organization_id: null,
    default_printer_id: null,
    muted_notification_types: [],
  },
  is_superuser: false,
  created_at: "2026-10-07T12:00:00Z",
};

function json(status: number, body: unknown): Response {
  const type = status >= 400 ? "application/problem+json" : "application/json";
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": type },
  });
}

function problem(status: number, code: string, detail = "Nope"): Response {
  return json(status, { type: "about:blank", title: "Error", status, code, detail });
}

/** A fake server: records requests and answers from a queue or a handler. */
function fakeFetch(handler: (request: Request, call: number) => Response | Promise<Response>) {
  const requests: Request[] = [];
  const fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const request = new Request(input, init);
    requests.push(request.clone());
    return handler(request, requests.length);
  };
  return { fetch, requests };
}

test("sends the access token to the right URL", async () => {
  const server = fakeFetch(() => json(200, USER));
  const api = createPrinterHubClient({
    baseUrl: `${BASE}/`,
    getAccessToken: () => "token-1",
    fetch: server.fetch,
  });

  const { data, error } = await api.GET("/api/v1/users/me");

  assert.equal(error, undefined);
  assert.equal(data?.email, "ada@example.com");
  assert.equal(server.requests[0]?.url, `${BASE}/api/v1/users/me`);
  assert.equal(server.requests[0]?.headers.get("Authorization"), "Bearer token-1");
});

test("fills path parameters and sends the idempotency key", async () => {
  const server = fakeFetch(() => json(201, { id: "job-1", type: "print", status: "queued" }));
  const api = createPrinterHubClient({ baseUrl: BASE, fetch: server.fetch });
  const key = newIdempotencyKey();

  await api.POST("/api/v1/organizations/{org_id}/jobs", {
    params: { path: { org_id: "org-1" }, header: { "Idempotency-Key": key } },
    body: { type: "print", printer_id: "printer-1", settings: { copies: 2 } },
  });

  const request = server.requests[0];
  assert.equal(request?.url, `${BASE}/api/v1/organizations/org-1/jobs`);
  assert.equal(request?.headers.get("Idempotency-Key"), key);
  assert.deepEqual(await request?.json(), {
    type: "print",
    printer_id: "printer-1",
    settings: { copies: 2 },
  });
});

test("returns a typed problem, and unwrap throws it", async () => {
  const server = fakeFetch(() =>
    json(422, {
      type: "about:blank",
      title: "Unprocessable Content",
      status: 422,
      code: "request.validation_failed",
      detail: "The request did not match the expected shape.",
      errors: [{ field: "body.password", message: "Too short", code: "string_too_short" }],
    }),
  );
  const api = createPrinterHubClient({ baseUrl: BASE, fetch: server.fetch });

  const result = await api.POST("/api/v1/auth/register", {
    body: { email: "ada@example.com", password: "short", name: "Ada" },
  });

  assert.equal(result.data, undefined);
  assert.equal(result.error?.code, "request.validation_failed");
  assert.throws(
    () => unwrap(result),
    (thrown: unknown) => {
      assert.ok(thrown instanceof ProblemError);
      assert.equal(thrown.status, 422);
      assert.equal(thrown.code, "request.validation_failed");
      assert.deepEqual(thrown.fieldErrors, { "body.password": "Too short" });
      return true;
    },
  );
});

test("unwrap returns the data of a successful call", async () => {
  const server = fakeFetch(() => json(200, USER));
  const api = createPrinterHubClient({ baseUrl: BASE, fetch: server.fetch });

  const me = unwrap(await api.GET("/api/v1/users/me"));

  assert.equal(me.name, "Ada");
});

test("refreshes an expired token and repeats the request with its body", async () => {
  let token = "expired";
  const server = fakeFetch((request) =>
    request.headers.get("Authorization") === "Bearer fresh"
      ? json(200, { ...USER, name: "Renamed" })
      : problem(401, "auth.token_expired"),
  );
  let refreshes = 0;
  const api = createPrinterHubClient({
    baseUrl: BASE,
    fetch: server.fetch,
    getAccessToken: () => token,
    refreshAccessToken: () => {
      refreshes += 1;
      token = "fresh";
      return token;
    },
  });

  const { data, error } = await api.PATCH("/api/v1/users/me", { body: { name: "Renamed" } });

  assert.equal(error, undefined);
  assert.equal(data?.name, "Renamed");
  assert.equal(refreshes, 1);
  assert.equal(server.requests.length, 2);
  assert.deepEqual(await server.requests[1]?.json(), { name: "Renamed" });
});

test("concurrent requests share one refresh", async () => {
  let token = "expired";
  const server = fakeFetch((request) =>
    request.headers.get("Authorization") === "Bearer fresh"
      ? json(200, USER)
      : problem(401, "auth.token_expired"),
  );
  let refreshes = 0;
  const api = createPrinterHubClient({
    baseUrl: BASE,
    fetch: server.fetch,
    getAccessToken: () => token,
    refreshAccessToken: async () => {
      refreshes += 1;
      await new Promise((resolve) => setTimeout(resolve, 10));
      token = "fresh";
      return token;
    },
  });

  const results = await Promise.all([
    api.GET("/api/v1/users/me"),
    api.GET("/api/v1/users/me"),
    api.GET("/api/v1/users/me"),
  ]);

  // Using a refresh token twice revokes the session, so this must be exactly one.
  assert.equal(refreshes, 1);
  assert.deepEqual(
    results.map((result) => result.response.status),
    [200, 200, 200],
  );
});

test("reports sign-out when the refresh fails", async () => {
  const server = fakeFetch(() => problem(401, "auth.token_expired"));
  const signedOut: (string | undefined)[] = [];
  const api = createPrinterHubClient({
    baseUrl: BASE,
    fetch: server.fetch,
    getAccessToken: () => "expired",
    refreshAccessToken: () => {
      throw new Error("refresh token rejected");
    },
    onSignedOut: (reason) => signedOut.push(reason?.code),
  });

  const { error, response } = await api.GET("/api/v1/users/me");

  assert.equal(response.status, 401);
  assert.equal(error?.code, "auth.token_expired");
  assert.deepEqual(signedOut, ["auth.token_expired"]);
  assert.equal(server.requests.length, 1);
});

test("a revoked session signs out without trying to refresh", async () => {
  const server = fakeFetch(() => problem(401, "auth.session_revoked"));
  let refreshes = 0;
  const signedOut: (string | undefined)[] = [];
  const api = createPrinterHubClient({
    baseUrl: BASE,
    fetch: server.fetch,
    getAccessToken: () => "revoked",
    refreshAccessToken: () => {
      refreshes += 1;
      return "fresh";
    },
    onSignedOut: (reason) => signedOut.push(reason?.code),
  });

  await api.GET("/api/v1/users/me");

  assert.equal(refreshes, 0);
  assert.deepEqual(signedOut, ["auth.session_revoked"]);
});

test("a wrong password at login is not treated as a lost session", async () => {
  const server = fakeFetch(() => problem(401, "auth.invalid_credentials"));
  let refreshes = 0;
  let signedOut = 0;
  const api = createPrinterHubClient({
    baseUrl: BASE,
    fetch: server.fetch,
    refreshAccessToken: () => {
      refreshes += 1;
      return "fresh";
    },
    onSignedOut: () => {
      signedOut += 1;
    },
  });

  const { error } = await api.POST("/api/v1/auth/login", {
    body: { email: "ada@example.com", password: "wrong" },
  });

  assert.equal(error?.code, "auth.invalid_credentials");
  assert.equal(refreshes, 0);
  assert.equal(signedOut, 0);
});

test("idempotency keys are unique", () => {
  assert.notEqual(newIdempotencyKey(), newIdempotencyKey());
  assert.match(newIdempotencyKey(), /^[0-9a-f-]{36}$/);
});
