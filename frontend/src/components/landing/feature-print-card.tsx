import { Icon } from "./icon";

export function FeaturePrintCard() {
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
					<title>Print Feature Illustration</title>
					<rect
						x="0"
						y="0"
						width="600"
						height="440"
						style={{ fill: "var(--bg)" }}
					/>
					<circle
						cx="300"
						cy="250"
						r="170"
						style={{ fill: "var(--p)", opacity: 0.35 }}
					/>
					<g transform="translate(150 190) scale(1.4)">
						<rect
							x="40"
							y="-12"
							width="140"
							height="16"
							rx="4"
							style={{
								fill: "#E6E6E6",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="14"
							y="0"
							width="192"
							height="46"
							rx="10"
							style={{
								fill: "#F4F4F4",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="0"
							y="40"
							width="220"
							height="118"
							rx="12"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="150"
							y="54"
							width="56"
							height="30"
							rx="6"
							style={{ fill: "var(--inv)" }}
						/>
						<rect
							x="156"
							y="60"
							width="44"
							height="18"
							rx="3"
							style={{ fill: "var(--p)" }}
						/>
						<rect
							x="30"
							y="94"
							width="140"
							height="10"
							rx="5"
							style={{ fill: "var(--inv)" }}
						/>
						<rect
							x="52"
							y="74"
							width="96"
							height="26"
							rx="2"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="1"
							y="124"
							width="218"
							height="6"
							style={{ fill: "var(--p)" }}
						/>
						<rect
							x="0"
							y="154"
							width="220"
							height="112"
							rx="10"
							style={{
								fill: "#EEEEEE",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="12"
							y="168"
							width="196"
							height="40"
							rx="6"
							style={{ fill: "#F8F8F8" }}
						/>
						<rect
							x="12"
							y="216"
							width="196"
							height="40"
							rx="6"
							style={{ fill: "#F8F8F8" }}
						/>
						<rect
							x="90"
							y="184"
							width="40"
							height="6"
							rx="3"
							style={{ fill: "#BDBDBD" }}
						/>
						<rect
							x="90"
							y="232"
							width="40"
							height="6"
							rx="3"
							style={{ fill: "#BDBDBD" }}
						/>
						<circle cx="22" cy="272" r="7" style={{ fill: "var(--inv)" }} />
						<circle cx="198" cy="272" r="7" style={{ fill: "var(--inv)" }} />
					</g>
					<g transform="translate(330 40) rotate(12)">
						<rect
							x="0"
							y="0"
							width="90"
							height="120"
							rx="3"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="12"
							y="18"
							width="66"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="12"
							y="32"
							width="50"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="12"
							y="46"
							width="66"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="12"
							y="60"
							width="50"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="12"
							y="80"
							width="40"
							height="26"
							rx="3"
							style={{ fill: "var(--p)" }}
						/>
					</g>
					<g transform="translate(400 70) rotate(24)">
						<rect
							x="0"
							y="0"
							width="90"
							height="120"
							rx="3"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="12"
							y="18"
							width="66"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="12"
							y="32"
							width="50"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="12"
							y="46"
							width="66"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="12"
							y="60"
							width="50"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="12"
							y="80"
							width="40"
							height="26"
							rx="3"
							style={{ fill: "var(--p)" }}
						/>
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
						<Icon name="print" size={20} />
					</div>
					<h3 style={{ margin: 0, fontSize: "21px", fontWeight: 700 }}>
						Print
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
					From files, photos or any app's share sheet. Duplex, colour, trays and
					finishing appear only when the printer has them.
				</p>
			</div>
		</div>
	);
}
