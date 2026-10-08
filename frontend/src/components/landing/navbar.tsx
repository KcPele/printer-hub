import { useState } from "react";
import { Icon } from "./icon";
import { useTheme } from "./theme-context";

export function Navbar() {
	const { theme, setTheme, currentTokens } = useTheme();
	const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

	const navLinks = [
		{ label: "Features", href: "#features" },
		{ label: "How it connects", href: "#connect" },
		{ label: "Privacy", href: "#privacy" },
		{ label: "Themes", href: "#themes" },
		{ label: "For teams", href: "#teams" },
	];

	const closeMenu = () => setMobileMenuOpen(false);

	return (
		<header
			style={{
				position: "sticky",
				top: 0,
				zIndex: 50,
				padding: "14px clamp(16px, 4vw, 24px)",
				background: "var(--bg)",
				borderBottom: "1px solid var(--line)",
				transition: "background-color 0.25s ease, border-color 0.25s ease",
			}}
		>
			<div
				style={{
					maxWidth: "1240px",
					margin: "0 auto",
					display: "flex",
					alignItems: "center",
					justifyContent: "space-between",
					gap: "16px",
				}}
			>
				{/* Brand Logo */}
				<a
					href="#top"
					style={{
						display: "flex",
						alignItems: "center",
						gap: "10px",
						color: "var(--tx)",
						flexShrink: 0,
					}}
				>
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
							transition: "background-color 0.2s ease, border-radius 0.2s ease",
						}}
					>
						<Icon name="print" size={22} filled />
					</div>
					<span
						style={{
							fontSize: "20px",
							fontWeight: 800,
							letterSpacing: "-0.02em",
						}}
					>
						PrinterHub
					</span>
				</a>

				{/* Desktop Navigation Links */}
				<nav
					className="hidden lg:flex"
					style={{
						gap: "24px",
						fontSize: "15px",
						fontWeight: 600,
						whiteSpace: "nowrap",
						minWidth: 0,
						flex: "1 1 0",
						justifyContent: "center",
					}}
				>
					{navLinks.map((link) => (
						<a
							key={link.href}
							href={link.href}
							style={{
								color: "var(--tx)",
								transition: "color 0.15s ease",
							}}
						>
							{link.label}
						</a>
					))}
				</nav>

				{/* Desktop Actions */}
				<div
					className="hidden lg:flex"
					style={{
						alignItems: "center",
						gap: "14px",
						flexShrink: 0,
						whiteSpace: "nowrap",
					}}
				>
					{/* Theme Selector Pill */}
					<div
						style={{
							display: "flex",
							alignItems: "center",
							gap: "6px",
							padding: "5px 6px",
							borderRadius: "999px",
							border: "1px solid var(--line)",
							background: "var(--sf)",
						}}
						title="Switch theme"
					>
						<button
							type="button"
							onClick={() => setTheme("volt")}
							aria-label="Volt theme"
							style={{
								width: "20px",
								height: "20px",
								borderRadius: "999px",
								background: "#FFFF1E",
								border:
									theme === "volt" ? "2px solid #212121" : "1px solid #777",
								cursor: "pointer",
								padding: 0,
								transform: theme === "volt" ? "scale(1.1)" : "none",
							}}
						/>
						<button
							type="button"
							onClick={() => setTheme("indigo")}
							aria-label="Indigo theme"
							style={{
								width: "20px",
								height: "20px",
								borderRadius: "999px",
								background: "#4856EB",
								border:
									theme === "indigo" ? "2px solid #FFFFFF" : "1px solid #777",
								cursor: "pointer",
								padding: 0,
								transform: theme === "indigo" ? "scale(1.1)" : "none",
							}}
						/>
						<button
							type="button"
							onClick={() => setTheme("mint")}
							aria-label="Mint theme"
							style={{
								width: "20px",
								height: "20px",
								borderRadius: "999px",
								background: "#46D7B7",
								border:
									theme === "mint" ? "2px solid #FFFFFF" : "1px solid #777",
								cursor: "pointer",
								padding: 0,
								transform: theme === "mint" ? "scale(1.1)" : "none",
							}}
						/>
						<span
							style={{
								fontFamily: "'JetBrains Mono', monospace",
								fontSize: "11px",
								fontWeight: 600,
								padding: "0 6px 0 2px",
								color: "var(--mt)",
							}}
						>
							{currentTokens.name}
						</span>
					</div>

					<a
						href="#get"
						style={{
							background: "var(--p)",
							color: "var(--onp)",
							padding: "11px 18px",
							borderRadius: "var(--rb)",
							fontWeight: 700,
							fontSize: "14px",
							display: "inline-block",
							transition: "background-color 0.2s ease, border-radius 0.2s ease",
						}}
					>
						Get the app
					</a>
				</div>

				{/* Mobile Hamburger Toggle */}
				<div className="flex lg:hidden">
					<button
						type="button"
						onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
						aria-label="Toggle navigation menu"
						aria-expanded={mobileMenuOpen}
						style={{
							width: "44px",
							height: "44px",
							borderRadius: "var(--rb)",
							border: "1px solid var(--line)",
							background: "var(--sf)",
							color: "var(--tx)",
							display: "flex",
							alignItems: "center",
							justifyContent: "center",
							cursor: "pointer",
							padding: 0,
							flexShrink: 0,
						}}
					>
						<Icon name={mobileMenuOpen ? "close" : "menu"} size={24} />
					</button>
				</div>
			</div>

			{/* Mobile Drawer Menu */}
			{mobileMenuOpen && (
				<div
					style={{
						position: "absolute",
						left: 0,
						right: 0,
						top: "100%",
						background: "var(--bg)",
						borderBottom: "1px solid var(--line)",
						boxShadow: "0 24px 40px -20px rgba(0,0,0,0.25)",
						padding: "8px clamp(16px, 4vw, 24px) 24px",
						display: "flex",
						flexDirection: "column",
						gap: "20px",
						maxHeight: "calc(100vh - 72px)",
						overflowY: "auto",
						boxSizing: "border-box",
					}}
				>
					<nav style={{ display: "flex", flexDirection: "column" }}>
						{navLinks.map((link) => (
							<a
								key={link.href}
								href={link.href}
								onClick={closeMenu}
								style={{
									display: "flex",
									alignItems: "center",
									justifyContent: "space-between",
									minHeight: "52px",
									fontSize: "18px",
									fontWeight: 700,
									borderBottom: "1px solid var(--line)",
									color: "var(--tx)",
								}}
							>
								{link.label}
								<Icon
									name="arrow_forward"
									size={20}
									style={{ color: "var(--mt)" }}
								/>
							</a>
						))}
					</nav>

					<div
						style={{
							display: "flex",
							alignItems: "center",
							justifyContent: "space-between",
							gap: "12px",
						}}
					>
						<span
							style={{ fontSize: "14px", fontWeight: 600, color: "var(--mt)" }}
						>
							Theme
						</span>
						<div
							style={{
								display: "flex",
								alignItems: "center",
								gap: "6px",
								padding: "5px 6px",
								borderRadius: "999px",
								border: "1px solid var(--line)",
								background: "var(--sf)",
							}}
							title="Switch theme"
						>
							<button
								type="button"
								onClick={() => setTheme("volt")}
								aria-label="Volt theme"
								style={{
									width: "20px",
									height: "20px",
									borderRadius: "999px",
									background: "#FFFF1E",
									border:
										theme === "volt" ? "2px solid #212121" : "1px solid #777",
									cursor: "pointer",
									padding: 0,
								}}
							/>
							<button
								type="button"
								onClick={() => setTheme("indigo")}
								aria-label="Indigo theme"
								style={{
									width: "20px",
									height: "20px",
									borderRadius: "999px",
									background: "#4856EB",
									border:
										theme === "indigo" ? "2px solid #FFFFFF" : "1px solid #777",
									cursor: "pointer",
									padding: 0,
								}}
							/>
							<button
								type="button"
								onClick={() => setTheme("mint")}
								aria-label="Mint theme"
								style={{
									width: "20px",
									height: "20px",
									borderRadius: "999px",
									background: "#46D7B7",
									border:
										theme === "mint" ? "2px solid #FFFFFF" : "1px solid #777",
									cursor: "pointer",
									padding: 0,
								}}
							/>
							<span
								style={{
									fontFamily: "'JetBrains Mono', monospace",
									fontSize: "11px",
									fontWeight: 600,
									padding: "0 6px 0 2px",
									color: "var(--mt)",
								}}
							>
								{currentTokens.name}
							</span>
						</div>
					</div>

					<button
						type="button"
						onClick={() => {
							closeMenu();
							const el = document.getElementById("get");
							if (el) {
								el.scrollIntoView({ behavior: "smooth" });
							} else {
								window.location.hash = "get";
							}
						}}
						style={{
							display: "flex",
							alignItems: "center",
							justifyContent: "center",
							minHeight: "52px",
							background: "var(--p)",
							color: "var(--onp)",
							borderRadius: "var(--rb)",
							fontWeight: 700,
							fontSize: "16px",
							border: "none",
							cursor: "pointer",
							width: "100%",
						}}
					>
						Get the app
					</button>
				</div>
			)}
		</header>
	);
}
