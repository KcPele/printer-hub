import { Icon } from "./icon";

export function Footer() {
	return (
		<footer
			style={{
				background: "var(--inv)",
				color: "#FFFFFF",
				padding: "72px 24px 32px",
				transition: "background-color 0.25s ease",
			}}
		>
			<div
				style={{
					maxWidth: "1240px",
					margin: "0 auto",
					display: "flex",
					flexDirection: "column",
					gap: "56px",
				}}
			>
				{/* Navigation Grid */}
				<div
					style={{
						display: "grid",
						gridTemplateColumns:
							"repeat(auto-fit, minmax(min(100%, 180px), 1fr))",
						gap: "40px",
					}}
				>
					{/* Brand Info (Span 2) */}
					<div
						className="md:col-span-2"
						style={{
							display: "flex",
							flexDirection: "column",
							gap: "16px",
							maxWidth: "360px",
						}}
					>
						<div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
							<div
								style={{
									width: "36px",
									height: "36px",
									borderRadius: "var(--rb)",
									background: "var(--p)",
									color: "var(--onp)",
									display: "flex",
									alignItems: "center",
									justifyContent: "center",
								}}
							>
								<Icon name="print" size={22} filled />
							</div>
							<span
								style={{
									fontSize: "20px",
									fontWeight: 800,
									letterSpacing: "-0.02em",
								}}
							>
								PrinterHub
							</span>
						</div>
						<p
							style={{
								margin: 0,
								fontSize: "15px",
								lineHeight: 1.55,
								color: "rgba(255,255,255,0.72)",
							}}
						>
							Printing, scanning and copying for every printer around you. Built
							for iOS and Android, with a web app for teams.
						</p>
					</div>

					{/* Product Links */}
					<div
						style={{
							display: "flex",
							flexDirection: "column",
							gap: "12px",
							fontSize: "15px",
						}}
					>
						<span
							style={{
								fontSize: "13px",
								fontWeight: 700,
								letterSpacing: "0.06em",
								textTransform: "uppercase",
								color: "var(--pe)",
							}}
						>
							Product
						</span>
						<a href="#features" style={{ color: "rgba(255,255,255,0.85)" }}>
							Features
						</a>
						<a href="#connect" style={{ color: "rgba(255,255,255,0.85)" }}>
							How it connects
						</a>
						<a href="#themes" style={{ color: "rgba(255,255,255,0.85)" }}>
							Themes
						</a>
						<a href="#teams" style={{ color: "rgba(255,255,255,0.85)" }}>
							Web app
						</a>
					</div>

					{/* Help Links */}
					<div
						style={{
							display: "flex",
							flexDirection: "column",
							gap: "12px",
							fontSize: "15px",
						}}
					>
						<span
							style={{
								fontSize: "13px",
								fontWeight: 700,
								letterSpacing: "0.06em",
								textTransform: "uppercase",
								color: "var(--pe)",
							}}
						>
							Help
						</span>
						<a href="#top" style={{ color: "rgba(255,255,255,0.85)" }}>
							Supported printers
						</a>
						<a href="#get" style={{ color: "rgba(255,255,255,0.85)" }}>
							Getting started
						</a>
						<a href="#teams" style={{ color: "rgba(255,255,255,0.85)" }}>
							Contact support
						</a>
					</div>

					{/* Company Links */}
					<div
						style={{
							display: "flex",
							flexDirection: "column",
							gap: "12px",
							fontSize: "15px",
						}}
					>
						<span
							style={{
								fontSize: "13px",
								fontWeight: 700,
								letterSpacing: "0.06em",
								textTransform: "uppercase",
								color: "var(--pe)",
							}}
						>
							Company
						</span>
						<a href="#top" style={{ color: "rgba(255,255,255,0.85)" }}>
							About
						</a>
						<a href="#privacy" style={{ color: "rgba(255,255,255,0.85)" }}>
							Privacy
						</a>
						<a href="#privacy" style={{ color: "rgba(255,255,255,0.85)" }}>
							Terms
						</a>
					</div>
				</div>

				{/* Bottom Bar */}
				<div
					style={{
						display: "flex",
						justifyContent: "space-between",
						gap: "16px",
						flexWrap: "wrap",
						paddingTop: "24px",
						borderTop: "1px solid rgba(255,255,255,0.14)",
						fontSize: "13px",
						color: "rgba(255,255,255,0.65)",
					}}
				>
					<span>© 2026 PrinterHub. All rights reserved.</span>
					<span>
						AirPrint, Mopria and other names belong to their respective owners.
					</span>
				</div>
			</div>
		</footer>
	);
}
