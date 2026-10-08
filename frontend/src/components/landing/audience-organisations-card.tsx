import type { CSSProperties } from "react";

export function AudienceOrganisationsCard({
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
				<title>Enterprise Network Infrastructure</title>
				<line
					x1="400"
					y1="210"
					x2="180"
					y2="110"
					style={{
						stroke: "var(--inv)",
						strokeWidth: 2,
						strokeDasharray: "4 7",
					}}
				/>
				<line
					x1="400"
					y1="210"
					x2="620"
					y2="90"
					style={{
						stroke: "var(--inv)",
						strokeWidth: 2,
						strokeDasharray: "4 7",
					}}
				/>
				<line
					x1="400"
					y1="210"
					x2="650"
					y2="320"
					style={{
						stroke: "var(--inv)",
						strokeWidth: 2,
						strokeDasharray: "4 7",
					}}
				/>
				<line
					x1="400"
					y1="210"
					x2="150"
					y2="310"
					style={{
						stroke: "var(--inv)",
						strokeWidth: 2,
						strokeDasharray: "4 7",
					}}
				/>
				<line
					x1="400"
					y1="210"
					x2="420"
					y2="60"
					style={{
						stroke: "var(--inv)",
						strokeWidth: 2,
						strokeDasharray: "4 7",
					}}
				/>

				<circle cx="400" cy="210" r="64" style={{ fill: "var(--p)" }} />
				<g transform="translate(352 182) scale(0.6)">
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

				{/* Node 1 */}
				<circle
					cx="180"
					cy="110"
					r="40"
					style={{
						fill: "var(--sf)",
						stroke: "var(--line)",
						strokeWidth: 2,
					}}
				/>
				<circle cx="208" cy="82" r="8" style={{ fill: "#1E9E5A" }} />

				{/* Node 2 */}
				<circle
					cx="620"
					cy="90"
					r="40"
					style={{
						fill: "var(--sf)",
						stroke: "var(--line)",
						strokeWidth: 2,
					}}
				/>
				<circle cx="648" cy="62" r="8" style={{ fill: "#1E9E5A" }} />

				{/* Node 3 */}
				<circle
					cx="650"
					cy="320"
					r="40"
					style={{
						fill: "var(--sf)",
						stroke: "var(--line)",
						strokeWidth: 2,
					}}
				/>
				<circle cx="678" cy="292" r="8" style={{ fill: "#E8A317" }} />

				{/* Node 4 */}
				<circle
					cx="150"
					cy="310"
					r="40"
					style={{
						fill: "var(--sf)",
						stroke: "var(--line)",
						strokeWidth: 2,
					}}
				/>
				<circle cx="178" cy="282" r="8" style={{ fill: "#1E9E5A" }} />

				{/* Node 5 */}
				<circle
					cx="420"
					cy="60"
					r="40"
					style={{
						fill: "var(--sf)",
						stroke: "var(--line)",
						strokeWidth: 2,
					}}
				/>
				<circle cx="448" cy="32" r="8" style={{ fill: "#1E9E5A" }} />
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
					Organisations
				</span>
				<span
					style={{
						fontSize: "14px",
						color: "var(--mt)",
						lineHeight: 1.45,
					}}
				>
					Many locations, roles and devices, with an audit log of who did what.
				</span>
			</div>
		</div>
	);
}
