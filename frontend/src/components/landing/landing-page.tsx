import { AudienceSection } from "./audience-section";
import { ConnectSection } from "./connect-section";
import { CtaSection } from "./cta-section";
import { FeaturesSection } from "./features-section";
import { Footer } from "./footer";
import { HeroSection } from "./hero-section";
import { Navbar } from "./navbar";
import { PrivacySection } from "./privacy-section";
import { StandardsStrip } from "./standards-strip";
import { TeamsSection } from "./teams-section";
import { ThemeProvider } from "./theme-context";
import { ThemesSection } from "./themes-section";

export function LandingPage() {
	return (
		<ThemeProvider>
			<div
				className="min-h-screen w-full flex flex-col"
				style={{
					background: "var(--bg)",
					color: "var(--tx)",
					fontFamily: "var(--font)",
					transition: "background-color 0.28s ease, color 0.28s ease",
				}}
			>
				<Navbar />
				<main className="flex-1 w-full">
					<HeroSection />
					<StandardsStrip />
					<FeaturesSection />
					<ConnectSection />
					<AudienceSection />
					<PrivacySection />
					<ThemesSection />
					<TeamsSection />
					<CtaSection />
				</main>
				<Footer />
			</div>
		</ThemeProvider>
	);
}
