/**
 * Compile-time checks. This file is never run: `pnpm typecheck` fails if the
 * API contract and the client's types drift apart.
 */
import { createPrinterHubClient, newIdempotencyKey, unwrap, type Job } from "../src/index.ts";

const api = createPrinterHubClient({ baseUrl: "https://api.example.test" });

export async function contractChecks(orgId: string, printerId: string): Promise<void> {
  // A job needs its idempotency key.
  await api.POST("/api/v1/organizations/{org_id}/jobs", {
    // @ts-expect-error missing the Idempotency-Key header
    params: { path: { org_id: orgId } },
    body: { type: "print", printer_id: printerId },
  });

  // Settings are checked against the job type.
  await api.POST("/api/v1/organizations/{org_id}/jobs", {
    params: { path: { org_id: orgId }, header: { "Idempotency-Key": newIdempotencyKey() } },
    // @ts-expect-error resolution_dpi is a scan setting, not a print setting
    body: { type: "print", printer_id: printerId, settings: { resolution_dpi: 300 } },
  });

  // Unknown routes do not compile.
  // @ts-expect-error no such path
  await api.GET("/api/v1/does-not-exist");

  // Results are discriminated by job type.
  const job: Job = unwrap(
    await api.POST("/api/v1/organizations/{org_id}/jobs", {
      params: { path: { org_id: orgId }, header: { "Idempotency-Key": newIdempotencyKey() } },
      body: { type: "scan", printer_id: printerId, settings: { source: "adf", duplex: true } },
    }),
  );
  if (job.type === "scan") {
    const dpi: number = job.settings.resolution_dpi;
    void dpi;
  } else if (job.type === "print") {
    const copies: number = job.settings.copies;
    void copies;
    // @ts-expect-error a print job has no scan settings
    void job.settings.resolution_dpi;
  }

  // Errors are typed.
  const { error } = await api.GET("/api/v1/organizations/{org_id}/printers", {
    params: { path: { org_id: orgId }, query: { limit: 20 } },
  });
  if (error) {
    const code: string = error.code;
    void code;
  }
}
