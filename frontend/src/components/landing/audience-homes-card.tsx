import type { CSSProperties } from "react";

export function AudienceHomesCard({
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
				<title>Home Printing Setup</title>
				<rect
					x="60"
					y="30"
					width="150"
					height="130"
					rx="8"
					style={{ fill: "#FFFFFF", opacity: 0.6 }}
				/>
				<rect
					x="133"
					y="30"
					width="4"
					height="130"
					style={{ fill: "#D9D9D9" }}
				/>
				<rect
					x="20"
					y="270"
					width="360"
					height="14"
					rx="4"
					style={{ fill: "var(--inv)" }}
				/>
				<rect
					x="40"
					y="284"
					width="10"
					height="146"
					rx="2"
					style={{ fill: "var(--inv)" }}
				/>
				<rect
					x="350"
					y="284"
					width="10"
					height="146"
					rx="2"
					style={{ fill: "var(--inv)" }}
				/>
				<g transform="translate(170 168) scale(1.1)">
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
				<g transform="translate(80 170)">
					<path
						d="M0 100 L20 20 L50 0"
						style={{ fill: "none", stroke: "var(--inv)", strokeWidth: 5 }}
					/>
					<rect
						x="34"
						y="-14"
						width="40"
						height="24"
						rx="12"
						style={{ fill: "var(--p)" }}
					/>
				</g>
				<g transform="translate(330 200) scale(0.8)">
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
					Homes
				</span>
				<span
					style={{
						fontSize: "14px",
						color: "var(--mt)",
						lineHeight: 1.45,
					}}
				>
					Homework and boarding passes, without the driver hunt.
				</span>
			</div>
		</div>
	);
}
