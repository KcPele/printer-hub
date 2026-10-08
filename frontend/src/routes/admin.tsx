import { createFileRoute } from "@tanstack/react-router";
import { AdminShell } from "../components/admin/admin-shell";

// The admin console keeps its sign-in in the browser, so nothing under it
// is rendered on the server.
export const Route = createFileRoute("/admin")({
	ssr: false,
	head: () => ({
		meta: [
			{ title: "PrinterHub admin" },
			{ name: "robots", content: "noindex, nofollow" },
		],
	}),
	component: AdminShell,
});
