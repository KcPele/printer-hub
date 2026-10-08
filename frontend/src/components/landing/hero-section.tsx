import { AppPhone } from "./app-phone";
import { HeroArtwork } from "./hero-artwork";
import { Icon } from "./icon";

export function HeroSection() {
	return (
		<section id="top" style={{ padding: "64px 24px 56px" }}>
			<div
				style={{
					maxWidth: "1240px",
					margin: "0 auto",
					display: "grid",
					gridTemplateColumns:
						"repeat(auto-fit, minmax(min(100%, 480px), 1fr))",
					gap: "48px",
					alignItems: "center",
				}}
			>
				{/* Left Column: Copy & Actions */}
				<div style={{ display: "flex", flexDirection: "column", gap: "28px" }}>
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
						PRINTERHUB FOR IOS AND ANDROID
					</span>

					<h1
						style={{
							margin: 0,
							fontSize: "clamp(46px, 6.2vw, 84px)",
							lineHeight: 0.98,
							letterSpacing: "-0.035em",
							fontWeight: 800,
							textWrap: "balance",
						}}
					>
						Find the printer. Tap it.{" "}
						<span
							style={{
								background: "var(--p)",
								color: "var(--onp)",
								padding: "0 0.14em",
								borderRadius: "var(--rb)",
								boxDecorationBreak: "clone",
								WebkitBoxDecorationBreak: "clone",
								transition:
									"background-color 0.2s ease, border-radius 0.2s ease",
							}}
						>
							Print.
						</span>
					</h1>

					<p
						style={{
							margin: 0,
							fontSize: "19px",
							lineHeight: 1.55,
							color: "var(--mt)",
							maxWidth: "520px",
							textWrap: "pretty",
						}}
					>
						PrinterHub finds the printers around you, works out what each one
						can do, and picks a connection that works. Printing, scanning and
						copying take one tap, not a networking lesson.
					</p>

					{/* App Store Buttons */}
					<div style={{ display: "flex", gap: "12px", flexWrap: "wrap" }}>
						<a
							href="#get"
							style={{
								display: "flex",
								alignItems: "center",
								gap: "10px",
								background: "var(--inv)",
								color: "#FFFFFF",
								padding: "12px 20px",
								borderRadius: "var(--rb)",
								transition: "transform 0.15s ease, border-radius 0.2s ease",
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
							href="#get"
							style={{
								display: "flex",
								alignItems: "center",
								gap: "10px",
								background: "var(--inv)",
								color: "#FFFFFF",
								padding: "12px 20px",
								borderRadius: "var(--rb)",
								transition: "transform 0.15s ease, border-radius 0.2s ease",
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

					{/* Value Props Bullet List */}
					<div
						style={{
							display: "flex",
							gap: "20px",
							flexWrap: "wrap",
							fontSize: "14px",
							fontWeight: 600,
							color: "var(--mt)",
						}}
					>
						<span style={{ display: "flex", alignItems: "center", gap: "6px" }}>
							<Icon
								name="check_circle"
								size={18}
								style={{ color: "var(--em)" }}
							/>
							No desktop driver
						</span>
						<span style={{ display: "flex", alignItems: "center", gap: "6px" }}>
							<Icon
								name="check_circle"
								size={18}
								style={{ color: "var(--em)" }}
							/>
							No server to install
						</span>
						<span style={{ display: "flex", alignItems: "center", gap: "6px" }}>
							<Icon
								name="check_circle"
								size={18}
								style={{ color: "var(--em)" }}
							/>
							Works offline on your network
						</span>
					</div>
				</div>

				{/* Right Column: Hero Visual Illustration */}
				<div
					style={{
						position: "relative",
						minHeight: "640px",
						borderRadius: "var(--rC)",
						overflow: "hidden",
						background: "var(--inv)",
						transition: "border-radius 0.2s ease",
					}}
				>
					{/* Vector Room Artwork */}
					<div style={{ position: "absolute", inset: 0 }}>
						<HeroArtwork />
					</div>

					<div
						style={{
							position: "absolute",
							inset: 0,
							background:
								"linear-gradient(90deg, var(--inv) 0%, rgba(0,0,0,0.35) 55%, rgba(0,0,0,0) 100%)",
							pointerEvents: "none",
						}}
					/>

					{/* Smartphone Mockup */}
					<div
						className="hidden sm:block"
						style={{
							position: "absolute",
							left: "8%",
							top: "30px",
							pointerEvents: "none",
						}}
					>
						<AppPhone />
					</div>

					{/* Floating Status Pill 1 */}
					<div
						style={{
							position: "absolute",
							right: "24px",
							top: "56px",
							background: "var(--sf)",
							border: "var(--bd)",
							boxShadow: "0 18px 40px -12px rgba(0,0,0,0.35)",
							borderRadius: "var(--rc)",
							padding: "14px 16px",
							display: "flex",
							alignItems: "center",
							gap: "12px",
							pointerEvents: "none",
							maxWidth: "calc(100% - 48px)",
						}}
					>
						<div
							style={{
								width: "38px",
								height: "38px",
								borderRadius: "var(--rb)",
								background: "var(--p)",
								color: "var(--onp)",
								display: "flex",
								alignItems: "center",
								justifyContent: "center",
							}}
						>
							<Icon name="wifi_find" size={22} />
						</div>
						<div style={{ display: "flex", flexDirection: "column" }}>
							<span
								style={{
									fontSize: "14px",
									fontWeight: 700,
									color: "var(--tx)",
								}}
							>
								3 printers nearby
							</span>
							<span style={{ fontSize: "12px", color: "var(--mt)" }}>
								Found on Office Wi-Fi
							</span>
						</div>
					</div>

					{/* Floating Status Pill 2: Printing Progress */}
					<div
						style={{
							position: "absolute",
							right: "24px",
							bottom: "48px",
							width: "230px",
							background: "var(--sf)",
							border: "var(--bd)",
							boxShadow: "0 18px 40px -12px rgba(0,0,0,0.35)",
							borderRadius: "var(--rc)",
							padding: "14px 16px",
							display: "flex",
							flexDirection: "column",
							gap: "10px",
							pointerEvents: "none",
						}}
					>
						<div
							style={{
								display: "flex",
								justifyContent: "space-between",
								alignItems: "baseline",
							}}
						>
							<span
								style={{
									fontSize: "14px",
									fontWeight: 700,
									color: "var(--tx)",
								}}
							>
								Printing
							</span>
							<span
								style={{
									fontFamily: "'JetBrains Mono', monospace",
									fontSize: "12px",
									color: "var(--mt)",
								}}
							>
								7 of 12
							</span>
						</div>
						<div
							style={{
								height: "6px",
								borderRadius: "999px",
								background: "var(--line)",
								overflow: "hidden",
							}}
						>
							<div
								style={{ width: "58%", height: "100%", background: "var(--p)" }}
							/>
						</div>
						<span style={{ fontSize: "12px", color: "var(--mt)" }}>
							Q3 report.pdf · Duplex · Colour
						</span>
					</div>
				</div>
			</div>
		</section>
	);
}
