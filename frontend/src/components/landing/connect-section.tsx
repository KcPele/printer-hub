import { Icon } from "./icon";

export function ConnectSection() {
	const discoveryMethods = [
		{
			icon: "wifi_find",
			title: "Nearby",
			description: "Printers on your Wi-Fi show up on their own.",
		},
		{
			icon: "dns",
			title: "Address",
			description: "Type an IP or hostname, and PrinterHub works out the rest.",
		},
		{
			icon: "qr_code_scanner",
			title: "QR code",
			description: "Scan the sticker your admin put on the printer.",
		},
		{
			icon: "nfc",
			title: "NFC tap",
			description: "Tap your phone on the printer to pair.",
		},
		{
			icon: "wifi_tethering",
			title: "Wi-Fi Direct",
			description: "Connect straight to the printer when there's no network.",
		},
		{
			icon: "bluetooth_searching",
			title: "Bluetooth",
			description: "Spot the closest printer as you walk up to it.",
		},
	];

	const capabilities = [
		"Colour",
		"Two-sided",
		"A3 and A4",
		"Staple",
		"Scan to PDF",
		"Copy",
	];

	return (
		<section
			id="connect"
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
					display: "flex",
					flexDirection: "column",
					gap: "48px",
				}}
			>
				{/* Section Header */}
				<div
					style={{
						display: "flex",
						flexDirection: "column",
						gap: "16px",
						maxWidth: "760px",
					}}
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
						HOW IT CONNECTS
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
						Six ways to find a printer. One printer at the end.
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
						Whichever way you add it, PrinterHub asks the device what it is and
						saves one printer with every route that reaches it.
					</p>
				</div>

				{/* 2-Column Comparison Layout */}
				<div
					style={{
						display: "grid",
						gridTemplateColumns:
							"repeat(auto-fit, minmax(min(100%, 520px), 1fr))",
						gap: "20px",
						alignItems: "stretch",
					}}
				>
					{/* Left: 6 Ways to Discover Grid */}
					<div
						style={{
							display: "grid",
							gridTemplateColumns:
								"repeat(auto-fit, minmax(min(100%, 180px), 1fr))",
							gap: "14px",
						}}
					>
						{discoveryMethods.map((method) => (
							<div
								key={method.title}
								style={{
									background: "var(--bg)",
									border: "var(--bd)",
									boxShadow: "var(--sh)",
									borderRadius: "var(--rc)",
									padding: "20px",
									display: "flex",
									flexDirection: "column",
									gap: "10px",
									transition: "all 0.2s ease",
								}}
							>
								<Icon
									name={method.icon}
									size={28}
									style={{ color: "var(--em)" }}
								/>
								<span
									style={{
										fontSize: "17px",
										fontWeight: 700,
										color: "var(--tx)",
									}}
								>
									{method.title}
								</span>
								<span
									style={{
										fontSize: "14px",
										lineHeight: 1.5,
										color: "var(--mt)",
									}}
								>
									{method.description}
								</span>
							</div>
						))}
					</div>

					{/* Right: Saved Printer Details Card */}
					<div
						style={{
							background: "var(--inv)",
							color: "#FFFFFF",
							borderRadius: "var(--rC)",
							padding: "32px",
							display: "flex",
							flexDirection: "column",
							gap: "24px",
						}}
					>
						<div
							style={{
								display: "flex",
								justifyContent: "space-between",
								alignItems: "flex-start",
								gap: "16px",
							}}
						>
							<div
								style={{ display: "flex", flexDirection: "column", gap: "4px" }}
							>
								<span
									style={{
										fontFamily: "'JetBrains Mono', monospace",
										fontSize: "12px",
										letterSpacing: "0.08em",
										textTransform: "uppercase",
										color: "var(--pe)",
										fontWeight: 600,
									}}
								>
									Printer saved
								</span>
								<span
									style={{
										fontSize: "28px",
										fontWeight: 800,
										letterSpacing: "-0.02em",
									}}
								>
									Xerox VersaLink C7130
								</span>
								<span
									style={{ fontSize: "14px", color: "rgba(255,255,255,0.72)" }}
								>
									Office · 2nd floor
								</span>
							</div>
							<span
								style={{
									display: "flex",
									alignItems: "center",
									gap: "6px",
									fontSize: "12px",
									fontWeight: 700,
									color: "#0E4D2C",
									background: "#BFEBD2",
									padding: "5px 10px",
									borderRadius: "999px",
									whiteSpace: "nowrap",
								}}
							>
								<span
									style={{
										width: "7px",
										height: "7px",
										borderRadius: "999px",
										background: "#1E9E5A",
									}}
								/>
								Online
							</span>
						</div>

						{/* What It Can Do Tags */}
						<div
							style={{ display: "flex", flexDirection: "column", gap: "10px" }}
						>
							<span
								style={{
									fontSize: "13px",
									fontWeight: 700,
									color: "rgba(255,255,255,0.72)",
								}}
							>
								What it can do
							</span>
							<div style={{ display: "flex", flexWrap: "wrap", gap: "8px" }}>
								{capabilities.map((cap) => (
									<span
										key={cap}
										style={{
											padding: "7px 12px",
											borderRadius: "var(--rb)",
											border: "1px solid rgba(255,255,255,0.22)",
											fontSize: "13px",
											fontWeight: 600,
										}}
									>
										{cap}
									</span>
								))}
							</div>
						</div>

						{/* Ordered Routes */}
						<div
							style={{
								display: "flex",
								flexDirection: "column",
								gap: "10px",
								marginTop: "auto",
							}}
						>
							<span
								style={{
									fontSize: "13px",
									fontWeight: 700,
									color: "rgba(255,255,255,0.72)",
								}}
							>
								Routes, tried in order
							</span>
							<div
								style={{ display: "flex", flexDirection: "column", gap: "8px" }}
							>
								{/* Route 01 */}
								<div
									style={{
										display: "flex",
										alignItems: "center",
										gap: "12px",
										padding: "12px 14px",
										borderRadius: "var(--rc)",
										background: "rgba(255,255,255,0.07)",
									}}
								>
									<span
										style={{
											fontFamily: "'JetBrains Mono', monospace",
											fontSize: "12px",
											color: "var(--pe)",
											fontWeight: 600,
										}}
									>
										01
									</span>
									<span style={{ flex: 1, fontSize: "15px", fontWeight: 600 }}>
										Secure IPP over office Wi-Fi
									</span>
									<Icon name="error" size={18} style={{ color: "#FF8A80" }} />
									<span
										style={{
											fontSize: "12px",
											color: "rgba(255,255,255,0.72)",
										}}
									>
										Timed out
									</span>
								</div>

								{/* Route 02 (Active) */}
								<div
									style={{
										display: "flex",
										alignItems: "center",
										gap: "12px",
										padding: "12px 14px",
										borderRadius: "var(--rc)",
										background: "rgba(255,255,255,0.14)",
										outline: "1px solid var(--pe)",
									}}
								>
									<span
										style={{
											fontFamily: "'JetBrains Mono', monospace",
											fontSize: "12px",
											color: "var(--pe)",
											fontWeight: 600,
										}}
									>
										02
									</span>
									<span style={{ flex: 1, fontSize: "15px", fontWeight: 600 }}>
										IPP over the local network
									</span>
									<Icon
										name="check_circle"
										size={18}
										style={{ color: "#6FE0A0" }}
									/>
									<span
										style={{
											fontSize: "12px",
											color: "rgba(255,255,255,0.9)",
										}}
									>
										Sent
									</span>
								</div>

								{/* Route 03 (Standby) */}
								<div
									style={{
										display: "flex",
										alignItems: "center",
										gap: "12px",
										padding: "12px 14px",
										borderRadius: "var(--rc)",
										background: "rgba(255,255,255,0.07)",
										opacity: 0.6,
									}}
								>
									<span
										style={{
											fontFamily: "'JetBrains Mono', monospace",
											fontSize: "12px",
											color: "var(--pe)",
											fontWeight: 600,
										}}
									>
										03
									</span>
									<span style={{ flex: 1, fontSize: "15px", fontWeight: 600 }}>
										Wi-Fi Direct
									</span>
									<span
										style={{
											fontSize: "12px",
											color: "rgba(255,255,255,0.72)",
										}}
									>
										Standby
									</span>
								</div>
							</div>
							<p
								style={{
									margin: "6px 0 0",
									fontSize: "14px",
									lineHeight: 1.5,
									color: "rgba(255,255,255,0.72)",
								}}
							>
								If one route fails, the next one takes over. You see one word:
								printed.
							</p>
						</div>
					</div>
				</div>
			</div>
		</section>
	);
}
