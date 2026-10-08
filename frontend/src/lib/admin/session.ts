import type { Tokens } from "@printerhub/api-client";
import { useSyncExternalStore } from "react";

/**
 * The admin console's sign-in: the two tokens the API gave.
 *
 * It is kept in the tab's session storage, so a reload stays signed in and
 * closing the tab signs out. Nothing is kept on the server that renders the
 * pages: the console only runs in the browser.
 */
export interface AdminSession {
	accessToken: string;
	refreshToken: string;
}

const KEY = "printerhub-admin-session";
const listeners = new Set<() => void>();
let current: AdminSession | null | undefined;

function read(): AdminSession | null {
	if (typeof window === "undefined") return null;
	try {
		const kept = window.sessionStorage.getItem(KEY);
		return kept ? (JSON.parse(kept) as AdminSession) : null;
	} catch {
		return null;
	}
}

function write(session: AdminSession | null) {
	current = session;
	try {
		if (session) {
			window.sessionStorage.setItem(KEY, JSON.stringify(session));
		} else {
			window.sessionStorage.removeItem(KEY);
		}
	} catch {
		// Storage is switched off: the sign-in lasts until the page is left.
	}
	for (const listener of listeners) listener();
}

export const adminSession = {
	get(): AdminSession | null {
		if (current === undefined) current = read();
		return current;
	},
	save(tokens: Tokens) {
		write({
			accessToken: tokens.access_token,
			refreshToken: tokens.refresh_token,
		});
	},
	clear() {
		write(null);
	},
	subscribe(listener: () => void) {
		listeners.add(listener);
		return () => {
			listeners.delete(listener);
		};
	},
};

/** The sign-in, for a component that should follow it. */
export function useAdminSession(): AdminSession | null {
	return useSyncExternalStore(
		adminSession.subscribe,
		adminSession.get,
		() => null,
	);
}
