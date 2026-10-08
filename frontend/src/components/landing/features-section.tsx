import { FeatureCopyCard } from "./feature-copy-card";
import { FeatureMonitorCard } from "./feature-monitor-card";
import { FeaturePrintCard } from "./feature-print-card";
import { FeatureScanCard } from "./feature-scan-card";

export function FeaturesSection() {
	return (
		<section id="features" style={{ padding: "104px 24px" }}>
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
						justifyContent: "space-between",
						alignItems: "flex-end",
						gap: "24px",
						flexWrap: "wrap",
					}}
				>
					<div
						style={{
							display: "flex",
							flexDirection: "column",
							gap: "16px",
							maxWidth: "680px",
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
							WHAT IT DOES
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
							Everything the printer does, from the phone in your hand.
						</h2>
					</div>
					<p
						style={{
							margin: 0,
							fontSize: "17px",
							lineHeight: 1.55,
							color: "var(--mt)",
							maxWidth: "400px",
							textWrap: "pretty",
						}}
					>
						PrinterHub reads what the device supports and only shows what will
						work, so there are no greyed-out options and no failed jobs.
					</p>
				</div>

				{/* 4 Feature Cards Grid */}
				<div
					style={{
						display: "grid",
						gridTemplateColumns:
							"repeat(auto-fit, minmax(min(100%, 270px), 1fr))",
						gap: "20px",
					}}
				>
					<FeaturePrintCard />
					<FeatureScanCard />
					<FeatureCopyCard />
					<FeatureMonitorCard />
				</div>
			</div>
		</section>
	);
}
