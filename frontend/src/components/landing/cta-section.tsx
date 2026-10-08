import { Icon } from "./icon";

export function CtaSection() {
	return (
		<section id="get" style={{ padding: "104px 24px" }}>
			<div
				style={{
					maxWidth: "1240px",
					margin: "0 auto",
					background: "var(--p)",
					color: "var(--onp)",
					borderRadius: "var(--rC)",
					overflow: "hidden",
					display: "grid",
					gridTemplateColumns:
						"repeat(auto-fit, minmax(min(100%, 440px), 1fr))",
					transition: "background-color 0.25s ease, border-radius 0.2s ease",
				}}
			>
				{/* Left Column: CTA Pitch & Stores */}
				<div
					style={{
						padding: "clamp(40px, 6vw, 72px)",
						display: "flex",
						flexDirection: "column",
						gap: "22px",
						justifyContent: "center",
					}}
				>
					<span
						style={{
							fontFamily: "'JetBrains Mono', monospace",
							fontSize: "13px",
							letterSpacing: "0.08em",
							textTransform: "uppercase",
							fontWeight: 600,
						}}
					>
						GET STARTED
					</span>

					<h2
						style={{
							margin: 0,
							fontSize: "clamp(36px, 4.6vw, 60px)",
							lineHeight: 1.02,
							letterSpacing: "-0.03em",
							fontWeight: 800,
							textWrap: "balance",
						}}
					>
						Your printer is ready when you are.
					</h2>

					<p
						style={{
							margin: 0,
							fontSize: "17px",
							lineHeight: 1.55,
							maxWidth: "440px",
						}}
					>
						Install PrinterHub, tap Add Printer, and print your first page in
						under a minute.
					</p>

					<div style={{ display: "flex", gap: "12px", flexWrap: "wrap" }}>
						<a
							href="#top"
							style={{
								display: "flex",
								alignItems: "center",
								gap: "10px",
								background: "var(--inv)",
								color: "#FFFFFF",
								padding: "12px 20px",
								borderRadius: "var(--rb)",
								transition: "border-radius 0.2s ease, transform 0.15s ease",
							}}
						>
							<Icon name="phone_iphone" size={26} />
							<span
								style={{
									display: "flex",
									flexDirection: "column",
									lineHeight: 1.15,
								}}
							>
								<span style={{ fontSize: "11px", opacity: 0.8 }}>
									Download on the
								</span>
								<span style={{ fontSize: "16px", fontWeight: 700 }}>
									App Store
								</span>
							</span>
						</a>

						<a
							href="#top"
							style={{
								display: "flex",
								alignItems: "center",
								gap: "10px",
								background: "var(--inv)",
								color: "#FFFFFF",
								padding: "12px 20px",
								borderRadius: "var(--rb)",
								transition: "border-radius 0.2s ease, transform 0.15s ease",
							}}
						>
							<Icon name="android" size={26} />
							<span
								style={{
									display: "flex",
									flexDirection: "column",
									lineHeight: 1.15,
								}}
							>
								<span style={{ fontSize: "11px", opacity: 0.8 }}>
									Get it on
								</span>
								<span style={{ fontSize: "16px", fontWeight: 700 }}>
									Google Play
								</span>
							</span>
						</a>
					</div>
				</div>

				{/* Right Column: Graphic Showcase */}
				<div style={{ minHeight: "420px", position: "relative" }}>
					<svg
						viewBox="0 0 600 420"
						preserveAspectRatio="xMidYMid slice"
						style={{
							position: "absolute",
							inset: 0,
							width: "100%",
							height: "100%",
							display: "block",
						}}
					>
						<title>PrinterHub Device and Laser Printer</title>
						<rect
							x="0"
							y="0"
							width="600"
							height="420"
							style={{ fill: "var(--bg)" }}
						/>
						<circle
							cx="300"
							cy="230"
							r="190"
							style={{ fill: "var(--p)", opacity: 0.3 }}
						/>

						<g transform="translate(250 100)">
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

						{/* Mobile device */}
						<g transform="translate(90 110) scale(1.4)">
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
								x="10"
								y="24"
								width="60"
								height="50"
								rx="8"
								style={{ fill: "var(--sf)" }}
							/>
							<rect
								x="10"
								y="82"
								width="60"
								height="16"
								rx="8"
								style={{ fill: "var(--p)" }}
							/>
							<rect
								x="10"
								y="104"
								width="40"
								height="8"
								rx="4"
								style={{ fill: "#D9D9D9" }}
							/>
						</g>

						{/* Flying sheet */}
						<g transform="translate(470 40) scale(0.7) rotate(18)">
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
			</div>
		</section>
	);
}
