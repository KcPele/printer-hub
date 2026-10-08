export function StandardsStrip() {
	const standards = [
		"AirPrint",
		"Mopria",
		"IPP Everywhere",
		"IPPS",
		"eSCL / AirScan",
		"Wi-Fi Direct",
		"Bonjour",
	];

	return (
		<section
			style={{
				padding: "28px 24px",
				borderTop: "1px solid var(--line)",
				borderBottom: "1px solid var(--line)",
				transition: "border-color 0.25s ease",
			}}
		>
			<div
				style={{
					maxWidth: "1240px",
					margin: "0 auto",
					display: "flex",
					alignItems: "center",
					justifyContent: "space-between",
					gap: "24px 40px",
					flexWrap: "wrap",
				}}
			>
				<span
					style={{
						fontFamily: "'JetBrains Mono', monospace",
						fontSize: "12px",
						letterSpacing: "0.08em",
						textTransform: "uppercase",
						color: "var(--mt)",
						fontWeight: 600,
					}}
				>
					Speaks the standards your printer already does
				</span>

				<div
					style={{
						display: "flex",
						gap: "14px 36px",
						flexWrap: "wrap",
						fontSize: "18px",
						fontWeight: 700,
						letterSpacing: "-0.01em",
						color: "var(--tx)",
					}}
				>
					{standards.map((standard) => (
						<span key={standard}>{standard}</span>
					))}
				</div>
			</div>
		</section>
	);
}
