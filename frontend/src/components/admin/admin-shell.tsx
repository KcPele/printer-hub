import { unwrap } from "@printerhub/api-client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Link, Outlet } from "@tanstack/react-router";
import { adminKeys, api, problemText } from "../../lib/admin/api";
import { adminSession, useAdminSession } from "../../lib/admin/session";
import { Icon } from "../landing/icon";
import { ThemeProvider } from "../landing/theme-context";
import { SignIn } from "./sign-in";
import { Button, Card, Notice } from "./ui";

const AREAS = [
	{ to: "/admin", label: "Overview", icon: "dashboard", exact: true },
	{
		to: "/admin/feature-switches",
		label: "Feature switches",
		icon: "toggle_on",
		exact: false,
	},
	{
		to: "/admin/printer-families",
		label: "Printer families",
		icon: "print",
		exact: false,
	},
] as const;

/**
 * Everything under /admin. Nobody gets past it without signing in, and
 * nobody but PrinterHub's own staff past that: the API refuses the rest in
 * any case, so this only saves them a screen of errors.
 */
export function AdminShell() {
	return (
		<ThemeProvider>
			<div
				className="min-h-screen w-full"
				style={{
					background: "var(--bg)",
					color: "var(--tx)",
					fontFamily: "var(--font)",
				}}
			>
				<Gate />
			</div>
		</ThemeProvider>
	);
}

function Gate() {
	const session = useAdminSession();
	const queryClient = useQueryClient();
	const me = useQuery({
		queryKey: adminKeys.me,
		queryFn: async () => unwrap(await api.GET("/api/v1/users/me")),
		enabled: session !== null,
		retry: false,
	});

	const signOut = async () => {
		// Told to the API so the session ends there too; signed out here
		// whether or not it hears.
		await api.POST("/api/v1/auth/logout").catch(() => undefined);
		adminSession.clear();
		queryClient.clear();
	};

	if (session === null) return <SignIn />;

	if (me.isPending) {
		return (
			<main className="flex min-h-screen items-center justify-center text-sm text-[var(--mt)]">
				Opening the admin console…
			</main>
		);
	}

	if (me.isError || !me.data.is_superuser) {
		return (
			<main className="flex min-h-screen items-center justify-center p-4">
				<Card className="flex w-full max-w-sm flex-col gap-4">
					<Notice>
						{me.isError
							? problemText(me.error)
							: `${me.data.email} is not a PrinterHub administrator. The admin console is for PrinterHub's own staff.`}
					</Notice>
					<Button onClick={signOut}>Sign in with another account</Button>
				</Card>
			</main>
		);
	}

	return (
		<>
			<header
				className="sticky top-0 z-10 bg-[var(--bg)]"
				style={{ borderBottom: "1px solid var(--line)" }}
			>
				{/* On a phone: the name and the way out on one row, the areas on a
				    row of their own. On a wide screen: one row. */}
				<div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-4 gap-y-2 px-4 py-3">
					<Link to="/admin" className="flex shrink-0 items-center gap-2">
						<span className="flex h-9 w-9 items-center justify-center rounded-[var(--rb)] bg-[var(--p)] text-[var(--onp)]">
							<Icon name="print" size={22} filled />
						</span>
						<span className="text-lg font-extrabold tracking-tight">
							PrinterHub admin
						</span>
					</Link>
					<div className="ml-auto flex min-w-0 items-center gap-3 lg:order-last">
						<span className="hidden min-w-0 truncate text-xs text-[var(--mt)] sm:block">
							{me.data.email}
						</span>
						<Button icon="logout" aria-label="Sign out" onClick={signOut}>
							<span className="hidden sm:inline">Sign out</span>
						</Button>
					</div>
					{/* Three equal tabs on a phone, so none is off the edge. */}
					<nav
						aria-label="Admin areas"
						className="grid w-full grid-cols-3 gap-1 sm:flex lg:w-auto lg:flex-1"
					>
						{AREAS.map((area) => (
							<Link
								key={area.to}
								to={area.to}
								activeOptions={{ exact: area.exact }}
								className="flex flex-col items-center gap-0.5 rounded-[var(--rb)] px-1 py-1.5 text-center text-xs font-bold text-[var(--mt)] sm:flex-row sm:gap-2 sm:px-3 sm:py-2 sm:text-sm"
								activeProps={{
									style: { background: "var(--sf)", color: "var(--tx)" },
								}}
							>
								<Icon name={area.icon} size={18} />
								{area.label}
							</Link>
						))}
					</nav>
				</div>
			</header>
			<main className="mx-auto max-w-6xl px-4 py-6 sm:py-8">
				<Outlet />
			</main>
		</>
	);
}
