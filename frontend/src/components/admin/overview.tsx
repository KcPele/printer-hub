import { unwrap } from "@printerhub/api-client";
import { useQuery } from "@tanstack/react-query";
import { Link } from "@tanstack/react-router";
import { API_URL, adminKeys, api, problemText } from "../../lib/admin/api";
import { Icon } from "../landing/icon";
import { Card, Notice, PageTitle } from "./ui";

/** What the console looks after, and how much of each there is. */
export function Overview() {
	const flags = useQuery({
		queryKey: adminKeys.flags,
		queryFn: async () => unwrap(await api.GET("/api/v1/admin/feature-flags")),
	});
	const families = useQuery({
		queryKey: adminKeys.families,
		queryFn: async () => unwrap(await api.GET("/api/v1/capability-profiles")),
	});
	const failed = flags.error ?? families.error;

	return (
		<>
			<PageTitle
				title="Overview"
				lead={`What every PrinterHub app is told, on ${API_URL}. A change here reaches every workspace at once.`}
			/>
			{failed ? <Notice>{problemText(failed)}</Notice> : null}
			<div className="mt-4 grid gap-4 md:grid-cols-2">
				<Area
					to="/admin/feature-switches"
					icon="toggle_on"
					title="Feature switches"
					figure={flags.data?.length}
					detail={
						flags.data
							? `${flags.data.filter((flag) => flag.enabled).length} on for everyone, ${flags.data.filter((flag) => flag.overrides.length > 0).length} set differently for a workspace`
							: "Loading…"
					}
				/>
				<Area
					to="/admin/printer-families"
					icon="print"
					title="Printer families"
					figure={families.data?.length}
					detail={
						families.data
							? `From ${new Set(families.data.map((family) => family.manufacturer)).size} makers, in the catalogue the app shows`
							: "Loading…"
					}
				/>
			</div>
		</>
	);
}

function Area({
	to,
	icon,
	title,
	figure,
	detail,
}: {
	to: "/admin/feature-switches" | "/admin/printer-families";
	icon: string;
	title: string;
	figure: number | undefined;
	detail: string;
}) {
	return (
		<Link to={to} className="block">
			<Card className="flex items-center gap-4">
				<span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-[var(--rb)] bg-[var(--p)] text-[var(--onp)]">
					<Icon name={icon} size={26} />
				</span>
				<span className="min-w-0 flex-1">
					<span className="block text-sm font-bold text-[var(--mt)]">
						{title}
					</span>
					<span className="block text-3xl font-extrabold tracking-tight">
						{figure ?? "–"}
					</span>
					<span className="block text-xs text-[var(--mt)]">{detail}</span>
				</span>
				<Icon name="chevron_right" size={22} />
			</Card>
		</Link>
	);
}
