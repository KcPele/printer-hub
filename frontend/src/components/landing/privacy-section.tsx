import { Icon } from "./icon";

export function PrivacySection() {
	const points = [
		{
			icon: "lan",
			title: "Local first",
			description:
				"Printing and scanning keep working when the internet doesn't.",
		},
		{
			icon: "lock",
			title: "Encrypted when stored",
			description:
				"Cloud documents and printer passwords are encrypted, and passwords are never sent back to any screen.",
		},
		{
			icon: "shield",
			title: "Printers stay private",
			description:
				"Nothing is opened to the internet. No port forwarding, ever.",
		},
	];

	return (
		<section id="privacy" style={{ padding: "0 24px" }}>
			<div
				style={{
					maxWidth: "1240px",
					margin: "0 auto",
					background: "var(--inv)",
					color: "#FFFFFF",
					borderRadius: "var(--rC)",
					padding: "clamp(40px, 6vw, 80px)",
					display: "grid",
					gridTemplateColumns:
						"repeat(auto-fit, minmax(min(100%, 360px), 1fr))",
					gap: "48px",
					transition: "border-radius 0.2s ease",
				}}
			>
				{/* Left Column */}
				<div style={{ display: "flex", flexDirection: "column", gap: "18px" }}>
					<span
						style={{
							fontFamily: "'JetBrains Mono', monospace",
							fontSize: "13px",
							letterSpacing: "0.08em",
							textTransform: "uppercase",
							color: "var(--pe)",
							fontWeight: 600,
						}}
					>
						{"// Privacy"}
					</span>
					<h2
						style={{
							margin: 0,
							fontSize: "clamp(34px, 4.2vw, 54px)",
							lineHeight: 1.04,
							letterSpacing: "-0.03em",
							fontWeight: 800,
							textWrap: "balance",
						}}
					>
						Your documents go straight to the printer.
					</h2>
					<p
						style={{
							margin: 0,
							fontSize: "17px",
							lineHeight: 1.55,
							color: "rgba(255,255,255,0.75)",
							textWrap: "pretty",
						}}
					>
						On your network, the phone talks to the printer directly. Our
						servers keep your account and job history in sync, not your pages.
					</p>
				</div>

				{/* Right Column: Key Commitments */}
				<div style={{ display: "flex", flexDirection: "column" }}>
					{points.map((point, idx) => (
						<div
							key={point.title}
							style={{
								display: "flex",
								gap: "18px",
								padding: "22px 0",
								borderBottom:
									idx < points.length - 1
										? "1px solid rgba(255,255,255,0.14)"
										: "none",
							}}
						>
							<Icon
								name={point.icon}
								size={28}
								style={{ color: "var(--pe)", flexShrink: 0 }}
							/>
							<div
								style={{ display: "flex", flexDirection: "column", gap: "4px" }}
							>
								<span style={{ fontSize: "18px", fontWeight: 700 }}>
									{point.title}
								</span>
								<span
									style={{
										fontSize: "15px",
										lineHeight: 1.5,
										color: "rgba(255,255,255,0.72)",
									}}
								>
									{point.description}
								</span>
							</div>
						</div>
					))}
				</div>
			</div>
		</section>
	);
}
