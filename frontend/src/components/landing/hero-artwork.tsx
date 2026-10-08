export function HeroArtwork() {
	return (
		<svg
			viewBox="0 0 600 640"
			preserveAspectRatio="xMidYMid slice"
			style={{
				position: "absolute",
				inset: 0,
				width: "100%",
				height: "100%",
				display: "block",
			}}
		>
			<title>PrinterHub Office Printer Setup</title>
			<rect
				x="0"
				y="0"
				width="600"
				height="640"
				style={{ fill: "var(--bg)" }}
			/>
			<rect
				x="330"
				y="60"
				width="230"
				height="190"
				rx="6"
				style={{ fill: "#FFFFFF", opacity: 0.55 }}
			/>
			<rect x="443" y="60" width="4" height="190" style={{ fill: "#D9D9D9" }} />
			<rect
				x="330"
				y="153"
				width="230"
				height="4"
				style={{ fill: "#D9D9D9" }}
			/>
			<rect
				x="0"
				y="470"
				width="600"
				height="170"
				style={{ fill: "#E3E3E3" }}
			/>
			<rect x="0" y="470" width="600" height="4" style={{ fill: "#D9D9D9" }} />

			{/* Central Office Laser Printer Graphic */}
			<g transform="translate(300 210) scale(1.1)">
				<rect
					x="40"
					y="-12"
					width="140"
					height="16"
					rx="4"
					style={{ fill: "#E6E6E6", stroke: "#D2D2D2", strokeWidth: 2 }}
				/>
				<rect
					x="14"
					y="0"
					width="192"
					height="46"
					rx="10"
					style={{ fill: "#F4F4F4", stroke: "#D2D2D2", strokeWidth: 2 }}
				/>
				<rect
					x="0"
					y="40"
					width="220"
					height="118"
					rx="12"
					style={{ fill: "#FFFFFF", stroke: "#D2D2D2", strokeWidth: 2 }}
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
					style={{ fill: "#FFFFFF", stroke: "#D2D2D2", strokeWidth: 2 }}
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
					style={{ fill: "#EEEEEE", stroke: "#D2D2D2", strokeWidth: 2 }}
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

			{/* Person silhouette */}
			<g transform="translate(560 330)">
				<circle cx="0" cy="0" r="20" style={{ fill: "#C98F65" }} />
				<rect
					x="-30"
					y="26"
					width="60"
					height="110"
					rx="26"
					style={{ fill: "var(--inv)" }}
				/>
			</g>

			{/* Office Plant */}
			<g transform="translate(80 400)">
				<rect
					x="-18"
					y="40"
					width="36"
					height="40"
					rx="6"
					style={{ fill: "var(--inv)" }}
				/>
				<circle cx="0" cy="24" r="22" style={{ fill: "var(--p)" }} />
				<circle cx="-18" cy="10" r="16" style={{ fill: "var(--p)" }} />
				<circle cx="18" cy="8" r="16" style={{ fill: "var(--p)" }} />
				<circle cx="0" cy="-6" r="16" style={{ fill: "var(--p)" }} />
			</g>
		</svg>
	);
}
