import { createFileRoute } from "@tanstack/react-router";
import { Overview } from "../components/admin/overview";

export const Route = createFileRoute("/admin/")({
	component: Overview,
});
