import { Icon } from "./icon";

export function FeatureMonitorCard() {
	return (
		<div
			style={{
				background: "var(--sf)",
				border: "var(--bd)",
				boxShadow: "var(--sh)",
				borderRadius: "var(--rC)",
				overflow: "hidden",
				display: "flex",
				flexDirection: "column",
				transition: "all 0.25s ease",
			}}
		>
			<div
				style={{
					height: "220px",
					position: "relative",
					overflow: "hidden",
				}}
			>
				<svg
					viewBox="0 0 600 440"
					preserveAspectRatio="xMidYMid slice"
					style={{
						position: "absolute",
						inset: 0,
						width: "100%",
						height: "100%",
						display: "block",
					}}
				>
					<title>Monitor Feature Illustration</title>
					<rect
						x="0"
						y="0"
						width="600"
						height="440"
						style={{ fill: "var(--bg)" }}
					/>
					<g transform="translate(120 90)">
						<rect
							x="0"
							y="0"
							width="64"
							height="260"
							rx="12"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="8"
							y="61.68"
							width="48"
							height="190.32"
							rx="8"
							style={{ fill: "#00A3E0" }}
						/>
						<rect
							x="20"
							y="-14"
							width="24"
							height="18"
							rx="4"
							style={{ fill: "#BDBDBD" }}
						/>
					</g>
					<g transform="translate(220 90)">
						<rect
							x="0"
							y="0"
							width="64"
							height="260"
							rx="12"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="8"
							y="120.24"
							width="48"
							height="131.76"
							rx="8"
							style={{ fill: "#D6338A" }}
						/>
						<rect
							x="20"
							y="-14"
							width="24"
							height="18"
							rx="4"
							style={{ fill: "#BDBDBD" }}
						/>
					</g>
					<g transform="translate(320 90)">
						<rect
							x="0"
							y="0"
							width="64"
							height="260"
							rx="12"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="8"
							y="210.52"
							width="48"
							height="41.48"
							rx="8"
							style={{ fill: "#E8B800" }}
						/>
						<rect
							x="20"
							y="-14"
							width="24"
							height="18"
							rx="4"
							style={{ fill: "#BDBDBD" }}
						/>
					</g>
					<g transform="translate(420 90)">
						<rect
							x="0"
							y="0"
							width="64"
							height="260"
							rx="12"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="8"
							y="29.96"
							width="48"
							height="222.04"
							rx="8"
							style={{ fill: "#2A2A2A" }}
						/>
						<rect
							x="20"
							y="-14"
							width="24"
							height="18"
							rx="4"
							style={{ fill: "#BDBDBD" }}
						/>
					</g>
					{/* Yellow Alert Badge */}
					<g transform="translate(370 40)">
						<rect
							x="0"
							y="0"
							width="170"
							height="54"
							rx="14"
							style={{ fill: "var(--inv)" }}
						/>
						<circle cx="28" cy="27" r="12" style={{ fill: "#E8A317" }} />
						<text
							x="48"
							y="24"
							style={{
								fontFamily: "var(--font)",
								fontSize: "15px",
								fontWeight: 700,
								fill: "#FFFFFF",
							}}
						>
							Yellow low
						</text>
						<text
							x="48"
							y="42"
							style={{
								fontFamily: "var(--font)",
								fontSize: "12px",
								fill: "#FFFFFF",
								opacity: 0.75,
							}}
						>
							17% left
						</text>
					</g>
				</svg>
			</div>
			<div
				style={{
					padding: "24px",
					display: "flex",
					flexDirection: "column",
					gap: "10px",
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
						<Icon name="monitor_heart" size={20} />
					</div>
					<h3 style={{ margin: 0, fontSize: "21px", fontWeight: 700 }}>
						Monitor
					</h3>
				</div>
				<p
					style={{
						margin: 0,
						fontSize: "15px",
						lineHeight: 1.55,
						color: "var(--mt)",
					}}
				>
					Toner, paper and jams in plain words, with a push notification before
					anyone finds out the hard way.
				</p>
			</div>
		</div>
	);
}
