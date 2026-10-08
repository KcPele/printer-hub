import { Icon } from "./icon";
import { TeamsConsoleArtwork } from "./teams-console-artwork";

export function TeamsSection() {
	const teamFeatures = [
		{
			icon: "groups",
			title: "Roles and permissions",
			description: "Decide who can print, scan or manage.",
		},
		{
			icon: "tune",
			title: "Shared presets",
			description: 'Save "Invoices, duplex, mono" once.',
		},
		{
			icon: "receipt_long",
			title: "Job history and audit",
			description: "Every job and change, with who and when.",
		},
		{
			icon: "notifications_active",
			title: "Alerts that reach you",
			description: "Low toner and jams pushed to the right people.",
		},
	];

	return (
		<section
			id="teams"
			style={{
				padding: "104px 24px",
				background: "var(--sf)",
				borderTop: "var(--bd)",
				borderBottom: "var(--bd)",
				transition: "all 0.25s ease",
			}}
		>
			<div
				style={{
					maxWidth: "1240px",
					margin: "0 auto",
					display: "grid",
					gridTemplateColumns:
						"repeat(auto-fit, minmax(min(100%, 460px), 1fr))",
					gap: "56px",
					alignItems: "center",
				}}
			>
				{/* Left: Web Console Admin Fleet Illustration */}
				<div
					style={{
						height: "520px",
						position: "relative",
						borderRadius: "var(--rC)",
						overflow: "hidden",
						background: "var(--bg)",
						border: "var(--bd)",
						boxShadow: "var(--sh)",
						transition: "border-radius 0.2s ease",
					}}
				>
					<TeamsConsoleArtwork />
				</div>

				{/* Right: Copy & Feature Grid */}
				<div style={{ display: "flex", flexDirection: "column", gap: "28px" }}>
					<div
						style={{ display: "flex", flexDirection: "column", gap: "16px" }}
					>
						<span
							style={{
								fontFamily: "'JetBrains Mono', monospace",
								fontSize: "13px",
								letterSpacing: "0.08em",
								textTransform: "uppercase",
								color: "var(--em)",
								fontWeight: 600,
							}}
						>
							FOR TEAMS
						</span>
						<h2
							style={{
								margin: 0,
								fontSize: "clamp(34px, 4.4vw, 56px)",
								lineHeight: 1.04,
								letterSpacing: "-0.03em",
								fontWeight: 800,
								textWrap: "balance",
							}}
						>
							Run every printer from one account.
						</h2>
						<p
							style={{
								margin: 0,
								fontSize: "17px",
								lineHeight: 1.55,
								color: "var(--mt)",
								textWrap: "pretty",
							}}
						>
							Admins manage people, printers and defaults on the phone or in the
							browser. Both use the same account and see the same history.
						</p>
					</div>

					<div
						style={{
							display: "grid",
							gridTemplateColumns:
								"repeat(auto-fit, minmax(min(100%, 220px), 1fr))",
							gap: "14px",
						}}
					>
						{teamFeatures.map((feat) => (
							<div
								key={feat.title}
								style={{
									display: "flex",
									gap: "12px",
									alignItems: "flex-start",
								}}
							>
								<Icon
									name={feat.icon}
									size={24}
									style={{ color: "var(--em)", flexShrink: 0 }}
								/>
								<div
									style={{
										display: "flex",
										flexDirection: "column",
										gap: "3px",
									}}
								>
									<span
										style={{
											fontSize: "16px",
											fontWeight: 700,
											color: "var(--tx)",
										}}
									>
										{feat.title}
									</span>
									<span
										style={{
											fontSize: "14px",
											lineHeight: 1.5,
											color: "var(--mt)",
										}}
									>
										{feat.description}
									</span>
								</div>
							</div>
						))}
					</div>

					<a
						href="#get"
						style={{
							alignSelf: "flex-start",
							display: "flex",
							alignItems: "center",
							gap: "8px",
							background: "var(--inv)",
							color: "#FFFFFF",
							padding: "14px 22px",
							borderRadius: "var(--rb)",
							fontWeight: 700,
							fontSize: "15px",
							transition: "border-radius 0.2s ease",
						}}
					>
						Talk to us about teams
						<Icon name="arrow_forward" size={18} />
					</a>
				</div>
			</div>
		</section>
	);
}
