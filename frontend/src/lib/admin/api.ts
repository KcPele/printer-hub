import {
	createPrinterHubClient,
	ProblemError,
	type Schemas,
} from "@printerhub/api-client";
import { adminSession } from "./session";

/**
 * Where the API is. Set `VITE_API_URL` to point somewhere else; without it a
 * development build talks to a backend on this machine and a production
 * build to the live one.
 */
export const API_URL: string =
	// `||`, not `??`: a build with the variable set to nothing means unset.
	import.meta.env.VITE_API_URL ||
	(import.meta.env.DEV
		? "http://localhost:8000"
		: "https://printerhub-backend.kcpele.com");

/** The API, signed in as whoever is signed in to the admin console. */
export const api = createPrinterHubClient({
	baseUrl: API_URL,
	getAccessToken: () => adminSession.get()?.accessToken,
	refreshAccessToken: async () => {
		const session = adminSession.get();
		if (!session) return null;
		const { data } = await api.POST("/api/v1/auth/refresh", {
			body: { refresh_token: session.refreshToken },
		});
		if (!data) return null;
		adminSession.save(data);
		return data.access_token;
	},
	onSignedOut: () => adminSession.clear(),
});

export type FeatureFlag = Schemas["FeatureFlagRead"];
export type PrinterFamily = Schemas["CapabilityProfileRead"];
export type PrinterFamilyWrite = Schemas["CapabilityProfileWrite"];

/** What the API said went wrong, in words for a person. */
export function problemText(error: unknown): string {
	if (error instanceof ProblemError) {
		const fields = Object.entries(error.fieldErrors).map(
			([field, message]) => `${field}: ${message}`,
		);
		return [error.message, ...fields].join(" · ");
	}
	if (error instanceof TypeError) {
		return `The API at ${API_URL} did not answer. Check that it is running and that it allows this site.`;
	}
	return error instanceof Error ? error.message : "Something went wrong.";
}

/** The keys the admin console's requests are remembered under. */
export const adminKeys = {
	me: ["admin", "me"] as const,
	flags: ["admin", "feature-flags"] as const,
	families: ["admin", "printer-families"] as const,
	workspaces: ["admin", "workspaces"] as const,
};
