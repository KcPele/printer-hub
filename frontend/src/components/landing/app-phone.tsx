import type { CSSProperties } from "react";
import { Icon } from "./icon";
import { PhonePrinterGraphic, PhoneTonerGauges } from "./phone-printer-card";
import { getThemeVars, type ThemeName } from "./theme-context";

interface AppPhoneProps {
	overrideTheme?: ThemeName;
	className?: string;
	style?: CSSProperties;
}

export function AppPhone({
	overrideTheme,
	className = "",
	style,
}: AppPhoneProps) {
	const containerVars = overrideTheme ? getThemeVars(overrideTheme) : {};

	return (
		<div
			className={`select-none ${className}`}
			style={{
				width: "280px",
				height: "580px",
				borderRadius: "46px",
				background: "#0E0E0E",
				padding: "9px",
				boxShadow: "0 30px 60px -20px rgba(0,0,0,0.35)",
				flexShrink: 0,
				boxSizing: "border-box",
				...containerVars,
				...style,
			}}
		>
			<div
				style={{
					width: "100%",
					height: "100%",
					borderRadius: "38px",
					background: "var(--bg)",
					overflow: "hidden",
					display: "flex",
					flexDirection: "column",
					fontFamily: "var(--font)",
					color: "var(--tx)",
					position: "relative",
				}}
			>
				{/* Status Bar */}
				<div
					style={{
						display: "flex",
						justifyContent: "space-between",
						alignItems: "center",
						padding: "14px 22px 6px",
						fontSize: "12px",
						fontWeight: 700,
					}}
				>
					<span>9:41</span>
					<div
						style={{
							width: "76px",
							height: "20px",
							borderRadius: "999px",
							background: "#0E0E0E",
							position: "absolute",
							left: "50%",
							top: "10px",
							transform: "translateX(-50%)",
						}}
					/>
					<div style={{ display: "flex", gap: "4px", alignItems: "center" }}>
						<Icon name="signal_cellular_alt" size={14} />
						<Icon name="wifi" size={14} />
						<Icon name="battery_full" size={15} />
					</div>
				</div>

				{/* Greeting Header */}
				<div
					style={{
						display: "flex",
						justifyContent: "space-between",
						alignItems: "center",
						padding: "10px 18px 12px",
					}}
				>
					<div style={{ display: "flex", flexDirection: "column", gap: "1px" }}>
						<span style={{ fontSize: "11px", color: "var(--mt)" }}>
							Good morning
						</span>
						<span
							style={{
								fontSize: "18px",
								fontWeight: 700,
								letterSpacing: "-0.01em",
							}}
						>
							Ada
						</span>
					</div>
					<div
						style={{
							width: "34px",
							height: "34px",
							borderRadius: "999px",
							background: "var(--p)",
							color: "var(--onp)",
							display: "flex",
							alignItems: "center",
							justifyContent: "center",
							fontSize: "12px",
							fontWeight: 700,
						}}
					>
						AO
					</div>
				</div>

				{/* Main Printer Card */}
				<div
					style={{
						margin: "0 14px",
						background: "var(--sf)",
						border: "var(--bd)",
						boxShadow: "var(--sh)",
						borderRadius: "var(--rc)",
						padding: "14px",
						display: "flex",
						flexDirection: "column",
						gap: "10px",
					}}
				>
					<div
						style={{
							display: "flex",
							justifyContent: "space-between",
							alignItems: "center",
						}}
					>
						<span
							style={{
								fontSize: "10px",
								fontWeight: 700,
								letterSpacing: "0.06em",
								textTransform: "uppercase",
								color: "var(--mt)",
							}}
						>
							Your printer
						</span>
						<span
							style={{
								display: "flex",
								alignItems: "center",
								gap: "5px",
								fontSize: "10px",
								fontWeight: 700,
								color: "#137A45",
								background: "#E3F5EA",
								padding: "3px 8px",
								borderRadius: "999px",
							}}
						>
							<span
								style={{
									width: "6px",
									height: "6px",
									borderRadius: "999px",
									background: "#1E9E5A",
								}}
							/>
							Ready
						</span>
					</div>

					<PhonePrinterGraphic />

					<div style={{ display: "flex", flexDirection: "column", gap: "1px" }}>
						<span style={{ fontSize: "14px", fontWeight: 700 }}>
							VersaLink C7130
						</span>
						<span style={{ fontSize: "10px", color: "var(--mt)" }}>
							Office · 2nd floor · via IPPS
						</span>
					</div>

					<PhoneTonerGauges />
				</div>

				{/* Action Buttons */}
				<div
					style={{
						display: "grid",
						gridTemplateColumns: "repeat(3, 1fr)",
						gap: "8px",
						margin: "10px 14px 0",
					}}
				>
					<div
						style={{
							background: "var(--p)",
							color: "var(--onp)",
							borderRadius: "var(--rc)",
							padding: "12px 6px",
							display: "flex",
							flexDirection: "column",
							alignItems: "center",
							gap: "4px",
						}}
					>
						<Icon name="print" size={20} />
						<span style={{ fontSize: "11px", fontWeight: 700 }}>Print</span>
					</div>
					<div
						style={{
							background: "var(--sf)",
							border: "var(--bd)",
							boxShadow: "var(--sh)",
							borderRadius: "var(--rc)",
							padding: "12px 6px",
							display: "flex",
							flexDirection: "column",
							alignItems: "center",
							gap: "4px",
						}}
					>
						<Icon name="document_scanner" size={20} />
						<span style={{ fontSize: "11px", fontWeight: 700 }}>Scan</span>
					</div>
					<div
						style={{
							background: "var(--sf)",
							border: "var(--bd)",
							boxShadow: "var(--sh)",
							borderRadius: "var(--rc)",
							padding: "12px 6px",
							display: "flex",
							flexDirection: "column",
							alignItems: "center",
							gap: "4px",
						}}
					>
						<Icon name="content_copy" size={20} />
						<span style={{ fontSize: "11px", fontWeight: 700 }}>Copy</span>
					</div>
				</div>

				{/* Recent Jobs */}
				<div
					style={{
						margin: "12px 14px 0",
						display: "flex",
						flexDirection: "column",
						gap: "6px",
					}}
				>
					<span
						style={{
							fontSize: "10px",
							fontWeight: 700,
							letterSpacing: "0.06em",
							textTransform: "uppercase",
							color: "var(--mt)",
						}}
					>
						Recent
					</span>
					<div
						style={{
							display: "flex",
							alignItems: "center",
							gap: "10px",
							background: "var(--sf)",
							border: "var(--bd)",
							boxShadow: "var(--sh)",
							borderRadius: "var(--rc)",
							padding: "9px 10px",
						}}
					>
						<div
							style={{
								width: "28px",
								height: "28px",
								borderRadius: "8px",
								background: "var(--inv)",
								color: "#FFFFFF",
								display: "flex",
								alignItems: "center",
								justifyContent: "center",
							}}
						>
							<Icon name="picture_as_pdf" size={16} />
						</div>
						<div
							style={{
								display: "flex",
								flexDirection: "column",
								flex: 1,
								minWidth: 0,
							}}
						>
							<span style={{ fontSize: "11px", fontWeight: 700 }}>
								Q3 report.pdf
							</span>
							<span style={{ fontSize: "9px", color: "var(--mt)" }}>
								12 pages · Printed 2 min ago
							</span>
						</div>
						<Icon name="check_circle" size={16} style={{ color: "#1E9E5A" }} />
					</div>
				</div>

				{/* Bottom Navigation */}
				<div
					style={{
						marginTop: "auto",
						display: "grid",
						gridTemplateColumns: "repeat(4, 1fr)",
						padding: "10px 8px 18px",
						background: "var(--sf)",
						borderTop: "1px solid var(--line)",
					}}
				>
					<div
						style={{
							display: "flex",
							flexDirection: "column",
							alignItems: "center",
							gap: "2px",
							color: "var(--em)",
						}}
					>
						<Icon name="home" size={20} filled />
						<span style={{ fontSize: "9px", fontWeight: 700 }}>Home</span>
					</div>
					<div
						style={{
							display: "flex",
							flexDirection: "column",
							alignItems: "center",
							gap: "2px",
							color: "var(--mt)",
						}}
					>
						<Icon name="print" size={20} />
						<span style={{ fontSize: "9px" }}>Printers</span>
					</div>
					<div
						style={{
							display: "flex",
							flexDirection: "column",
							alignItems: "center",
							gap: "2px",
							color: "var(--mt)",
						}}
					>
						<Icon name="history" size={20} />
						<span style={{ fontSize: "9px" }}>Activity</span>
					</div>
					<div
						style={{
							display: "flex",
							flexDirection: "column",
							alignItems: "center",
							gap: "2px",
							color: "var(--mt)",
						}}
					>
						<Icon name="settings" size={20} />
						<span style={{ fontSize: "9px" }}>Settings</span>
					</div>
				</div>
			</div>
		</div>
	);
}
