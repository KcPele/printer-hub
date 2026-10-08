import { AudienceHomesCard } from "./audience-homes-card";
import { AudienceOfficesCard } from "./audience-offices-card";
import { AudienceOrganisationsCard } from "./audience-organisations-card";
import { AudiencePrintshopsCard } from "./audience-printshops-card";
import { AudienceSchoolsCard } from "./audience-schools-card";

export function AudienceSection() {
	return (
		<section style={{ padding: "104px 24px" }}>
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
						flexDirection: "column",
						gap: "16px",
						alignItems: "center",
						textAlign: "center",
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
						WHO IT'S FOR
					</span>
					<h2
						style={{
							margin: 0,
							fontSize: "clamp(34px, 4.4vw, 56px)",
							lineHeight: 1.04,
							letterSpacing: "-0.03em",
							fontWeight: 800,
							textWrap: "balance",
							maxWidth: "780px",
						}}
					>
						From the kitchen table to the print room.
					</h2>
				</div>

				{/* 2-Row Bento Grid */}
				<div
					style={{
						display: "flex",
						flexDirection: "column",
						gap: "16px",
						maxWidth: "1240px",
						width: "100%",
						margin: "0 auto",
					}}
				>
					{/* Row 1: Offices (wider 2.3fr), Homes (1fr), Print shops (1fr) */}
					<div className="audience-row-1">
						<AudienceOfficesCard />
						<AudienceHomesCard />
						<AudiencePrintshopsCard />
					</div>

					{/* Row 2: Schools (1fr), Organisations (wider 2fr) */}
					<div className="audience-row-2">
						<AudienceSchoolsCard />
						<AudienceOrganisationsCard />
					</div>
				</div>
			</div>
		</section>
	);
}
