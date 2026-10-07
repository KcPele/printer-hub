/**
 * Typed client for the PrinterHub API.
 *
 * Paths, parameters, request bodies, and responses are checked against
 * `schema.d.ts`, which is generated from `backend/openapi.json`. Regenerate it
 * with `pnpm api:generate` whenever the backend contract changes.
 */
import createClient, { type Client, type Middleware } from "openapi-fetch";

import type { components, paths } from "./schema";

export type { components, paths };

export type Schemas = components["schemas"];

/** The body of every error response. Branch on `code`, show `detail`. */
export type Problem = Schemas["Problem"];
export type FieldError = Schemas["FieldError"];

export type User = Schemas["UserRead"];
export type Tokens = Schemas["TokenResponse"];
export type Organization = Schemas["OrganizationRead"];
export type Printer = Schemas["PrinterRead"];
export type Connection = Schemas["ConnectionRead"];
export type PrinterCapabilities = Schemas["PrinterCapabilities-Output"];
export type Job =
  | Schemas["PrintJobRead"]
  | Schemas["ScanJobRead"]
  | Schemas["CopyJobRead"];
export type JobCreate =
  | Schemas["PrintJobCreate"]
  | Schemas["ScanJobCreate"]
  | Schemas["CopyJobCreate"];
export type JobStatus = Schemas["JobStatus"];
export type Document = Schemas["DocumentRead"];
export type Notification = Schemas["NotificationRead"];

type MaybePromise<T> = T | Promise<T>;

export interface PrinterHubClientOptions {
  /** Origin of the API, for example `https://printerhub-backend.kcpele.com`. */
  baseUrl: string;
  /** Returns the stored access token, or nothing when signed out. */
  getAccessToken?: () => MaybePromise<string | null | undefined>;
  /**
   * Exchanges the stored refresh token for a new pair, saves it, and returns
   * the new access token. Return nothing when the refresh fails.
   *
   * Called at most once at a time: the API revokes a session whose refresh
   * token is used twice, so concurrent requests share one refresh.
   */
  refreshAccessToken?: () => MaybePromise<string | null | undefined>;
  /** Called when a request is refused and the session cannot be recovered. */
  onSignedOut?: (problem: Problem | undefined) => void;
  /** Defaults to the global `fetch`. */
  fetch?: typeof globalThis.fetch;
}

export type PrinterHubClient = Client<paths>;

/** Requests that are made without a session, so a 401 from them is final. */
const SESSIONLESS_PATHS: ReadonlySet<string> = new Set([
  "/api/v1/auth/login",
  "/api/v1/auth/register",
  "/api/v1/auth/refresh",
  "/api/v1/auth/password/forgot",
  "/api/v1/auth/password/reset",
]);

const EXPIRED_TOKEN = "auth.token_expired";

export function isProblem(value: unknown): value is Problem {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as Problem).code === "string" &&
    typeof (value as Problem).status === "number"
  );
}

async function readProblem(response: Response): Promise<Problem | undefined> {
  try {
    const body: unknown = await response.clone().json();
    return isProblem(body) ? body : undefined;
  } catch {
    return undefined;
  }
}

export function createPrinterHubClient(
  options: PrinterHubClientOptions,
): PrinterHubClient {
  const send = options.fetch ?? globalThis.fetch;
  const client = createClient<paths>({
    baseUrl: options.baseUrl.replace(/\/+$/, ""),
    fetch: (request) => send(request),
  });

  // A request body can be read once, so a copy is kept for the retry that
  // follows a token refresh.
  const retryable = new Map<string, Request>();
  let refreshing: Promise<string | null> | null = null;

  const refreshOnce = (
    refresh: NonNullable<PrinterHubClientOptions["refreshAccessToken"]>,
  ): Promise<string | null> => {
    refreshing ??= Promise.resolve()
      .then(refresh)
      .then((token) => token ?? null)
      .catch(() => null)
      .finally(() => {
        refreshing = null;
      });
    return refreshing;
  };

  const auth: Middleware = {
    async onRequest({ request, schemaPath, id }) {
      const token = await options.getAccessToken?.();
      if (token) {
        request.headers.set("Authorization", `Bearer ${token}`);
      }
      if (options.refreshAccessToken && !SESSIONLESS_PATHS.has(schemaPath)) {
        retryable.set(id, request.clone());
      }
      return request;
    },

    async onResponse({ response, schemaPath, id }) {
      const original = retryable.get(id);
      retryable.delete(id);
      if (response.status !== 401 || SESSIONLESS_PATHS.has(schemaPath)) {
        return undefined;
      }

      const problem = await readProblem(response);
      if (
        problem?.code === EXPIRED_TOKEN &&
        original &&
        options.refreshAccessToken
      ) {
        const token = await refreshOnce(options.refreshAccessToken);
        if (token) {
          original.headers.set("Authorization", `Bearer ${token}`);
          return send(original);
        }
      }
      options.onSignedOut?.(problem);
      return undefined;
    },

    onError({ id }) {
      retryable.delete(id);
    },
  };

  client.use(auth);
  return client;
}

/** An API error, thrown by {@link unwrap}. */
export class ProblemError extends Error {
  readonly status: number;
  /** Stable machine-readable code, for example `job.invalid_transition`. */
  readonly code: string;
  readonly problem: Problem | undefined;

  constructor(status: number, problem: Problem | undefined) {
    super(problem?.detail ?? problem?.title ?? `Request failed with status ${status}`);
    this.name = "ProblemError";
    this.status = status;
    this.code = problem?.code ?? `http.${status}`;
    this.problem = problem;
  }

  /** Per-field messages of a validation error, keyed by field path. */
  get fieldErrors(): Record<string, string> {
    return Object.fromEntries(
      (this.problem?.errors ?? []).map((error) => [error.field, error.message]),
    );
  }
}

/**
 * Returns the data of a client call, or throws {@link ProblemError}.
 *
 * ```ts
 * const me = unwrap(await api.GET("/api/v1/users/me"));
 * ```
 *
 * Useful with libraries such as TanStack Query that expect failures to throw.
 */
export function unwrap<T>(result: {
  data?: T;
  error?: unknown;
  response: Response;
}): T {
  if (result.error !== undefined || !result.response.ok) {
    throw new ProblemError(
      result.response.status,
      isProblem(result.error) ? result.error : undefined,
    );
  }
  return result.data as T;
}

/**
 * A fresh `Idempotency-Key`. Create one per job the user submits and reuse
 * it on every retry of that request, so a lost response never prints twice.
 *
 * React Native needs a `crypto.randomUUID` polyfill such as `expo-crypto`.
 */
export function newIdempotencyKey(): string {
  return globalThis.crypto.randomUUID();
}
