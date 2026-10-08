import { AppPhone } from "./app-phone";
import { getThemeVars, type ThemeName, useTheme } from "./theme-context";

export function ThemesSection() {
	const { theme: activeTheme, setTheme } = useTheme();

	const themesList: Array<{
		id: ThemeName;
		name: string;
		tagline: string;
		fontFamily: string;
		badgeBg: string;
		badgeColor: string;
		badgeRadius: string;
	}> = [
		{
			id: "volt",
			name: "Volt",
			tagline: "Bold, high contrast",
			fontFamily: "'Outfit', sans-serif",
			badgeBg: "#212121",
			badgeColor: "#FFFF1E",
			badgeRadius: "999px",
		},
		{
			id: "indigo",
			name: "Indigo",
			tagline: "Soft, friendly",
			fontFamily: "'Plus Jakarta Sans', sans-serif",
			badgeBg: "#4856EB",
			badgeColor: "#FFFFFF",
			badgeRadius: "16px",
		},
		{
			id: "mint",
			name: "Mint",
			tagline: "Clean, technical · default",
			fontFamily: "'Manrope', sans-serif",
			badgeBg: "#46D7B7",
			badgeColor: "#0B3B32",
			badgeRadius: "12px",
		},
	];

	return (
		<section id="themes" style={{ padding: "104px 24px" }}>
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
							MAKE IT YOURS
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
							One app, three looks.
						</h2>
					</div>
					<p
						style={{
							margin: 0,
							fontSize: "17px",
							lineHeight: 1.55,
							color: "var(--mt)",
							maxWidth: "420px",
							textWrap: "pretty",
						}}
					>
						Pick Volt, Indigo or Mint in Settings and it changes at once. Same
						screens, same buttons in the same places. Tap one below to try it on
						this page.
					</p>
				</div>

				{/* 3 Theme Cards Grid */}
				<div
					style={{
						display: "grid",
						gridTemplateColumns:
							"repeat(auto-fit, minmax(min(100%, 340px), 1fr))",
						gap: "20px",
					}}
				>
					{themesList.map((t) => {
						const isCurrent = activeTheme === t.id;
						const themeVars = getThemeVars(t.id);

						return (
							<button
								key={t.id}
								type="button"
								onClick={() => setTheme(t.id)}
								style={{
									...themeVars,
									all: "unset",
									cursor: "pointer",
									background:
										t.id === "volt"
											? "#EEEEEE"
											: t.id === "indigo"
												? "#EFF2FA"
												: "#FFFFFF",
									borderRadius: "var(--rC)",
									padding: "36px 24px 28px",
									display: "flex",
									flexDirection: "column",
									alignItems: "center",
									gap: "24px",
									boxSizing: "border-box",
									border: isCurrent
										? "2px solid var(--p)"
										: "1px solid var(--line)",
									boxShadow: isCurrent
										? "0 12px 30px -10px rgba(0,0,0,0.15)"
										: "none",
									transition: "all 0.25s ease",
									position: "relative",
								}}
							>
								{/* Embedded Phone Mockup in this theme */}
								<AppPhone overrideTheme={t.id} />

								{/* Theme Card Footer */}
								<div
									style={{
										display: "flex",
										alignItems: "center",
										justifyContent: "space-between",
										width: "100%",
										maxWidth: "300px",
										fontFamily: t.fontFamily,
										color:
											t.id === "volt"
												? "#212121"
												: t.id === "indigo"
													? "#1C1E2B"
													: "#1A1A1A",
									}}
								>
									<div
										style={{
											display: "flex",
											flexDirection: "column",
											gap: "2px",
											textAlign: "left",
										}}
									>
										<span style={{ fontSize: "22px", fontWeight: 700 }}>
											{t.name}
										</span>
										<span
											style={{
												fontSize: "13px",
												color:
													t.id === "volt"
														? "#5B5B5B"
														: t.id === "indigo"
															? "#585D73"
															: "#5E6366",
											}}
										>
											{t.tagline}
										</span>
									</div>

									<span
										style={{
											fontSize: "13px",
											fontWeight: 700,
											background: t.badgeBg,
											color: t.badgeColor,
											padding: "8px 14px",
											borderRadius: t.badgeRadius,
											whiteSpace: "nowrap",
											transition: "all 0.2s ease",
										}}
									>
										{isCurrent ? "In use" : "Try it"}
									</span>
								</div>
							</button>
						);
					})}
				</div>
			</div>
		</section>
	);
}
