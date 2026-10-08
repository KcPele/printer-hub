import type { CSSProperties } from "react";

export function AudienceSchoolsCard({
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
				viewBox="0 0 400 430"
				preserveAspectRatio="xMidYMid slice"
				style={{
					position: "absolute",
					inset: 0,
					width: "100%",
					height: "100%",
					display: "block",
				}}
			>
				<title>Schools Education Printing</title>
				<rect
					x="40"
					y="40"
					width="200"
					height="120"
					rx="8"
					style={{ fill: "var(--inv)" }}
				/>
				<text
					x="60"
					y="90"
					style={{
						fontFamily: "var(--font)",
						fontSize: "22px",
						fontWeight: 700,
						fill: "#FFFFFF",
					}}
				>
					a² + b² = c²
				</text>
				<rect
					x="60"
					y="110"
					width="120"
					height="4"
					rx="2"
					style={{ fill: "var(--p)" }}
				/>
				<g transform="translate(250 40)">
					<rect
						x="0"
						y="0"
						width="120"
						height="280"
						rx="6"
						style={{ fill: "#E6E6E6" }}
					/>
					<rect
						x="0"
						y="64"
						width="120"
						height="6"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="10"
						y="20"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "#BDBDBD" }}
					/>
					<rect
						x="31"
						y="20"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--p)" }}
					/>
					<rect
						x="52"
						y="20"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="73"
						y="20"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--p)" }}
					/>
					<rect
						x="94"
						y="20"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="0"
						y="134"
						width="120"
						height="6"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="10"
						y="90"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "#BDBDBD" }}
					/>
					<rect
						x="31"
						y="90"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--p)" }}
					/>
					<rect
						x="52"
						y="90"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="73"
						y="90"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--p)" }}
					/>
					<rect
						x="94"
						y="90"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="0"
						y="204"
						width="120"
						height="6"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="10"
						y="160"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "#BDBDBD" }}
					/>
					<rect
						x="31"
						y="160"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--p)" }}
					/>
					<rect
						x="52"
						y="160"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="73"
						y="160"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--p)" }}
					/>
					<rect
						x="94"
						y="160"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="0"
						y="274"
						width="120"
						height="6"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="10"
						y="230"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "#BDBDBD" }}
					/>
					<rect
						x="31"
						y="230"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--p)" }}
					/>
					<rect
						x="52"
						y="230"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="73"
						y="230"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--p)" }}
					/>
					<rect
						x="94"
						y="230"
						width="16"
						height="44"
						rx="2"
						style={{ fill: "var(--inv)" }}
					/>
				</g>
				<g transform="translate(40 220) scale(0.9)">
					<rect
						x="14"
						y="0"
						width="132"
						height="22"
						rx="8"
						style={{ fill: "#F4F4F4", stroke: "#D2D2D2", strokeWidth: 2 }}
					/>
					<rect
						x="0"
						y="18"
						width="160"
						height="74"
						rx="12"
						style={{
							fill: "#FFFFFF",
							stroke: "#D2D2D2",
							strokeWidth: 2,
						}}
					/>
					<rect
						x="110"
						y="28"
						width="36"
						height="16"
						rx="4"
						style={{ fill: "var(--inv)" }}
					/>
					<circle cx="118" cy="36" r="3" style={{ fill: "var(--p)" }} />
					<rect
						x="1"
						y="52"
						width="158"
						height="5"
						style={{ fill: "var(--p)" }}
					/>
					<rect
						x="36"
						y="60"
						width="88"
						height="8"
						rx="4"
						style={{ fill: "var(--inv)" }}
					/>
					<rect
						x="46"
						y="44"
						width="68"
						height="20"
						rx="2"
						style={{
							fill: "#FFFFFF",
							stroke: "#D2D2D2",
							strokeWidth: 2,
						}}
					/>
					<rect
						x="6"
						y="86"
						width="148"
						height="18"
						rx="8"
						style={{
							fill: "#EEEEEE",
							stroke: "#D2D2D2",
							strokeWidth: 2,
						}}
					/>
				</g>
				<rect
					x="0"
					y="340"
					width="400"
					height="90"
					style={{ fill: "#E3E3E3" }}
				/>
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
				}}
			>
				<span
					style={{
						fontSize: "18px",
						fontWeight: 700,
						color: "var(--tx)",
					}}
				>
					Schools
				</span>
				<span
					style={{
						fontSize: "14px",
						color: "var(--mt)",
						lineHeight: 1.45,
					}}
				>
					Staff print from any room on the network.
				</span>
			</div>
		</div>
	);
}
