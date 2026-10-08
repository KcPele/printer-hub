import { createFileRoute } from "@tanstack/react-router";
import { PrinterFamilies } from "../components/admin/printer-families";

export const Route = createFileRoute("/admin/printer-families")({
	component: PrinterFamilies,
});
