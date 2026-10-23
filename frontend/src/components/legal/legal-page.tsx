import type { ReactNode } from "react";
import { Icon } from "../landing/icon";
import { ThemeProvider } from "../landing/theme-context";

/**
 * A page of plain words: the privacy policy, how to delete an account.
 * The site's colours and type, a way home, and the words laid out to be
 * read on a phone.
 */
export function LegalPage({
	title,
	lead,
	children,
}: {
	title: string;
	lead: string;
	children: ReactNode;
}) {
	return (
		<ThemeProvider>
			<div
				className="min-h-screen w-full flex flex-col"
				style={{
					background: "var(--bg)",
					color: "var(--tx)",
					fontFamily: "var(--font)",
				}}
			>
				<header
					style={{
						padding: "14px clamp(16px, 4vw, 24px)",
						borderBottom: "1px solid var(--line)",
					}}
				>
					<a
						href="/"
						style={{
							maxWidth: "760px",
							margin: "0 auto",
							display: "flex",
							alignItems: "center",
							gap: "10px",
							color: "var(--tx)",
							fontWeight: 800,
							fontSize: "18px",
						}}
					>
						<span
							style={{
								width: "32px",
								height: "32px",
								borderRadius: "var(--rb)",
								background: "var(--p)",
								color: "var(--onp)",
								display: "flex",
								alignItems: "center",
								justifyContent: "center",
							}}
						>
							<Icon name="print" size={20} filled />
						</span>
						PrinterHub
					</a>
				</header>
				<main
					className="legal"
					style={{
						flex: 1,
						width: "100%",
						maxWidth: "760px",
						margin: "0 auto",
						padding: "48px clamp(16px, 4vw, 24px) 96px",
					}}
				>
					<h1
						style={{
							margin: 0,
							fontSize: "clamp(32px, 6vw, 44px)",
							lineHeight: 1.1,
							letterSpacing: "-0.02em",
							fontWeight: 800,
						}}
					>
						{title}
					</h1>
					<p
						style={{
							margin: "16px 0 0",
							fontSize: "18px",
							lineHeight: 1.6,
							color: "var(--mt)",
						}}
					>
						{lead}
					</p>
					{children}
				</main>
				<footer
					style={{
						borderTop: "1px solid var(--line)",
						padding: "24px clamp(16px, 4vw, 24px)",
						fontSize: "14px",
						color: "var(--mt)",
					}}
				>
					<div
						style={{
							maxWidth: "760px",
							margin: "0 auto",
							display: "flex",
							gap: "20px",
							flexWrap: "wrap",
						}}
					>
						<a href="/" style={{ color: "var(--em)" }}>
							Home
						</a>
						<a href="/privacy" style={{ color: "var(--em)" }}>
							Privacy policy
						</a>
						<a href="/delete-account" style={{ color: "var(--em)" }}>
							Delete your account
						</a>
					</div>
				</footer>
			</div>
		</ThemeProvider>
	);
}

/** A section of a legal page, with its heading. */
export function LegalSection({
	id,
	title,
	children,
}: {
	id?: string;
	title: string;
	children: ReactNode;
}) {
	return (
		<section id={id} style={{ marginTop: "40px" }}>
			<h2
				style={{
					margin: "0 0 12px",
					fontSize: "22px",
					lineHeight: 1.3,
					fontWeight: 700,
				}}
			>
				{title}
			</h2>
			<div
				style={{
					display: "flex",
					flexDirection: "column",
					gap: "12px",
					fontSize: "16px",
					lineHeight: 1.65,
				}}
			>
				{children}
			</div>
		</section>
	);
}
