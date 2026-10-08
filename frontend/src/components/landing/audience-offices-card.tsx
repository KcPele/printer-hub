import type { CSSProperties } from "react";

export function AudienceOfficesCard({
	className = "",
	style,
}: {
	className?: string;
	style?: CSSProperties;
}) {
	return (
		<div
			className={className}
			style={{
				position: "relative",
				borderRadius: "var(--rC)",
				overflow: "hidden",
				height: "280px",
				...style,
			}}
		>
			<svg
				viewBox="0 0 800 420"
				preserveAspectRatio="xMidYMid slice"
				style={{
					position: "absolute",
					inset: 0,
					width: "100%",
					height: "100%",
					display: "block",
				}}
			>
				<title>Offices Shared Printing Setup</title>
				<rect
					x="0"
					y="300"
					width="800"
					height="120"
					style={{ fill: "#E3E3E3" }}
				/>
				<line
					x1="160"
					y1="0"
					x2="160"
					y2="60"
					style={{ stroke: "var(--inv)", strokeWidth: 2 }}
				/>
				<circle cx="160" cy="70" r="16" style={{ fill: "var(--p)" }} />
				<line
					x1="330"
					y1="0"
					x2="330"
					y2="60"
					style={{ stroke: "var(--inv)", strokeWidth: 2 }}
				/>
				<circle cx="330" cy="70" r="16" style={{ fill: "var(--p)" }} />
				<g transform="translate(60 200)">
					<rect
						x="0"
						y="60"
						width="150"
						height="10"
						rx="3"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="10"
						y="70"
						width="8"
						height="80"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="132"
						y="70"
						width="8"
						height="80"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="30"
						y="0"
						width="90"
						height="56"
						rx="6"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="36"
						y="6"
						width="78"
						height="42"
						rx="3"
						style={{ fill: "var(--p)", opacity: 0.6 }}
					/>
					<rect
						x="68"
						y="56"
						width="14"
						height="6"
						style={{ fill: "var(--inv)" }}
					/>
				</g>
				<g transform="translate(230 200)">
					<rect
						x="0"
						y="60"
						width="150"
						height="10"
						rx="3"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="10"
						y="70"
						width="8"
						height="80"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="132"
						y="70"
						width="8"
						height="80"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="30"
						y="0"
						width="90"
						height="56"
						rx="6"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="36"
						y="6"
						width="78"
						height="42"
						rx="3"
						style={{ fill: "var(--p)", opacity: 0.6 }}
					/>
					<rect
						x="68"
						y="56"
						width="14"
						height="6"
						style={{ fill: "var(--inv)" }}
					/>
				</g>
				<g transform="translate(560 110) scale(0.95)">
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
				<g transform="translate(720 170) scale(0.85)">
					<circle cx="0" cy="0" r="20" style={{ fill: "#8D5A3B" }} />
					<rect
						x="-30"
						y="26"
						width="60"
						height="110"
						rx="26"
						style={{ fill: "var(--inv)" }}
					/>
				</g>
			</svg>
			<div
				style={{
					position: "absolute",
					left: "16px",
					right: "16px",
					bottom: "16px",
					background: "var(--bg)",
					borderRadius: "var(--rc)",
					padding: "16px 18px",
					display: "flex",
					flexDirection: "column",
					gap: "4px",
					pointerEvents: "none",
					maxWidth: "360px",
				}}
			>
				<span
					style={{
						fontSize: "18px",
						fontWeight: 700,
						color: "var(--tx)",
					}}
				>
					Offices
				</span>
				<span
					style={{
						fontSize: "14px",
						color: "var(--mt)",
						lineHeight: 1.45,
					}}
				>
					Shared printers, presets and scan destinations for the whole team.
				</span>
			</div>
		</div>
	);
}
