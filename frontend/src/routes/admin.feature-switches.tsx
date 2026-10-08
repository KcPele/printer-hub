import { createFileRoute } from "@tanstack/react-router";
import { FeatureSwitches } from "../components/admin/feature-switches";

export const Route = createFileRoute("/admin/feature-switches")({
	component: FeatureSwitches,
});
