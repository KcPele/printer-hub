import { Icon } from "./icon";

export function FeatureScanCard() {
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
					<title>Scan Feature Illustration</title>
					<rect
						x="0"
						y="0"
						width="600"
						height="440"
						style={{ fill: "var(--bg)" }}
					/>
					<g transform="translate(130 140)">
						<rect
							x="-20"
							y="-110"
							width="300"
							height="110"
							rx="12"
							style={{
								fill: "#F4F4F4",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="0"
							y="0"
							width="260"
							height="170"
							rx="14"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="14"
							y="12"
							width="232"
							height="90"
							rx="6"
							style={{ fill: "var(--p)", opacity: 0.25 }}
						/>
						<rect
							x="40"
							y="22"
							width="110"
							height="70"
							rx="2"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="50"
							y="34"
							width="60"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="50"
							y="48"
							width="80"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="50"
							y="62"
							width="50"
							height="6"
							rx="3"
							style={{ fill: "#D9D9D9" }}
						/>
						<rect
							x="14"
							y="56"
							width="232"
							height="6"
							rx="3"
							style={{ fill: "var(--p)" }}
						/>
						<rect
							x="0"
							y="130"
							width="260"
							height="40"
							style={{ fill: "#EEEEEE" }}
						/>
					</g>
					<path
						d="M410 230 C 450 230, 450 170, 480 170"
						style={{
							fill: "none",
							stroke: "var(--inv)",
							strokeWidth: 3,
							strokeDasharray: "6 8",
						}}
					/>
					<g transform="translate(460 120)">
						<rect
							x="0"
							y="0"
							width="80"
							height="160"
							rx="16"
							style={{ fill: "var(--inv)" }}
						/>
						<rect
							x="5"
							y="5"
							width="70"
							height="150"
							rx="12"
							style={{ fill: "var(--bg)" }}
						/>
						<rect
							x="30"
							y="9"
							width="20"
							height="5"
							rx="2.5"
							style={{ fill: "var(--inv)" }}
						/>
						<rect
							x="14"
							y="30"
							width="52"
							height="64"
							rx="4"
							style={{
								fill: "#FFFFFF",
								stroke: "#D2D2D2",
								strokeWidth: 2,
							}}
						/>
						<rect
							x="22"
							y="104"
							width="36"
							height="10"
							rx="5"
							style={{ fill: "var(--p)" }}
						/>
						<text
							x="22"
							y="70"
							style={{
								fontFamily: "var(--font)",
								fontSize: "13px",
								fontWeight: 800,
								fill: "var(--inv)",
							}}
						>
							PDF
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
						<Icon name="document_scanner" size={20} />
					</div>
					<h3 style={{ margin: 0, fontSize: "21px", fontWeight: 700 }}>Scan</h3>
				</div>
				<p
					style={{
						margin: 0,
						fontSize: "15px",
						lineHeight: 1.55,
						color: "var(--mt)",
					}}
				>
					Pull pages from the printer's scanner straight to a PDF on your phone.
					No scanner nearby? Use the camera instead.
				</p>
			</div>
		</div>
	);
}
