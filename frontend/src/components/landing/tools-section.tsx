import { Icon } from "./icon";

/** What the app does with no printer in reach: the phone's own tools. */
const tools = [
	{
		icon: "document_scanner",
		title: "Scan with the camera",
		description:
			"The camera finds each page and straightens it. Save a PDF or pictures.",
	},
	{
		icon: "crop",
		title: "Crop and highlight",
		description:
			"Open any picture full screen, trim it, turn it, and mark it in five inks.",
	},
	{
		icon: "picture_as_pdf",
		title: "PDFs and pictures, both ways",
		description:
			"Photos into one PDF, a PDF into pictures, or every page as one long image.",
	},
	{
		icon: "merge",
		title: "Merge files, keep pages",
		description:
			"Join PDFs and pictures in any order, or keep only the pages you need.",
	},
	{
		icon: "photo_library",
		title: "Photo pages",
		description:
			"One, two or four photos to a page, or a sheet of passport photos at true size.",
	},
	{
		icon: "qr_code_2",
		title: "Signs, notes and ruled pages",
		description:
			"A QR code for your Wi-Fi, a typed note, lined paper, a calendar. No file needed.",
	},
];

const kept = [
	{
		icon: "cloud_done",
		title: "Saved without asking",
		description: "Every scan and everything a tool makes is kept for you.",
	},
	{
		icon: "devices",
		title: "On any phone you sign in on",
		description:
			"Made offline, it waits on the phone and syncs when you are back online.",
	},
	{
		icon: "lock_person",
		title: "Yours until you share it",
		description:
			"Nobody else in the workspace sees a document until you choose to share.",
	},
];

const eyebrow = {
	fontFamily: "'JetBrains Mono', monospace",
	fontSize: "13px",
	letterSpacing: "0.08em",
	textTransform: "uppercase",
	color: "var(--em)",
	fontWeight: 600,
} as const;

const card = {
	background: "var(--sf)",
	border: "var(--bd)",
	boxShadow: "var(--sh)",
	borderRadius: "var(--rC)",
	overflow: "hidden",
	transition: "all 0.25s ease",
} as const;

/** A phone with a scanned page on it, being cropped and highlighted. */
function EditingArtwork() {
	return (
		<svg
			viewBox="0 0 600 470"
			preserveAspectRatio="xMidYMid meet"
			// Shown whole, whatever shape the space beside the tools is.
			style={{ width: "100%", height: "100%", display: "block" }}
		>
			<title>A scanned page being cropped and highlighted on a phone</title>
			<circle cx="436" cy="168" r="150" style={{ fill: "var(--p)" }} />

			{/* The phone */}
			<rect
				x="190"
				y="34"
				width="220"
				height="400"
				rx="30"
				style={{ fill: "var(--inv)" }}
			/>
			<rect x="202" y="48" width="196" height="380" rx="20" fill="#0E0E10" />
			<rect x="270" y="58" width="60" height="8" rx="4" fill="#2A2A2E" />

			{/* The page */}
			<rect x="224" y="92" width="152" height="204" rx="4" fill="#FFFFFF" />
			<rect x="238" y="110" width="84" height="9" rx="4" fill="#1A1A1A" />
			<rect
				x="232"
				y="134"
				width="128"
				height="14"
				rx="7"
				style={{ fill: "var(--p)", opacity: 0.55 }}
			/>
			{[138, 158, 178, 198, 218, 238, 258].map((y, index) => (
				<rect
					key={y}
					x="238"
					y={y}
					width={index % 3 === 2 ? 76 : 116}
					height="6"
					rx="3"
					fill="#C9CDD1"
				/>
			))}
			<rect
				x="232"
				y="212"
				width="96"
				height="14"
				rx="7"
				fill="#FF80AB"
				opacity="0.5"
			/>

			{/* The crop box, with its corners */}
			<rect
				x="216"
				y="84"
				width="168"
				height="220"
				fill="none"
				stroke="#FFFFFF"
				strokeWidth="2"
			/>
			{[
				[216, 84],
				[384, 84],
				[216, 304],
				[384, 304],
			].map(([x, y]) => (
				<circle key={`${x}-${y}`} cx={x} cy={y} r="7" fill="#FFFFFF" />
			))}

			{/* The inks, and the two pens */}
			{["#FFEB3B", "#69F0AE", "#FF80AB", "#40C4FF", "#FFAB40"].map(
				(ink, index) => (
					<circle
						key={ink}
						cx={228 + index * 26}
						cy={346}
						r="9"
						fill={ink}
						stroke={index === 2 ? "#FFFFFF" : "none"}
						strokeWidth="2.5"
					/>
				),
			)}
			<rect x="356" y="344" width="18" height="4" rx="2" fill="#FF80AB" />
			<rect x="352" y="358" width="26" height="10" rx="5" fill="#2A2A2E" />
			<rect x="224" y="384" width="68" height="8" rx="4" fill="#3A3A40" />
			<rect
				x="308"
				y="378"
				width="68"
				height="20"
				rx="10"
				style={{ fill: "var(--p)" }}
			/>

			{/* What came of it */}
			<g transform="translate(60 150)">
				<rect
					width="104"
					height="132"
					rx="10"
					style={{ fill: "var(--sf)", stroke: "var(--line)", strokeWidth: 2 }}
				/>
				<rect x="16" y="18" width="72" height="60" rx="4" fill="#FFFFFF" />
				<rect
					x="16"
					y="18"
					width="72"
					height="60"
					rx="4"
					fill="none"
					style={{ stroke: "var(--line)", strokeWidth: 2 }}
				/>
				<rect
					x="24"
					y="30"
					width="46"
					height="8"
					rx="4"
					style={{ fill: "var(--p)", opacity: 0.6 }}
				/>
				<rect x="24" y="46" width="56" height="5" rx="2.5" fill="#C9CDD1" />
				<rect x="24" y="58" width="40" height="5" rx="2.5" fill="#C9CDD1" />
				<rect
					x="16"
					y="92"
					width="52"
					height="8"
					rx="4"
					style={{ fill: "var(--tx)" }}
				/>
				<rect
					x="16"
					y="108"
					width="34"
					height="6"
					rx="3"
					style={{ fill: "var(--mt)", opacity: 0.6 }}
				/>
			</g>
			<g transform="translate(436 214)">
				<rect
					width="110"
					height="110"
					rx="14"
					style={{ fill: "var(--sf)", stroke: "var(--line)", strokeWidth: 2 }}
				/>
				{[0, 1, 2].map((row) =>
					[0, 1, 2].map((column) => (
						<rect
							key={`${row}-${column}`}
							x={20 + column * 25}
							y={20 + row * 25}
							width="20"
							height="20"
							rx="4"
							style={{
								fill: (row + column) % 2 === 0 ? "var(--inv)" : "var(--p)",
							}}
						/>
					)),
				)}
			</g>
		</svg>
	);
}

/** A list of kept documents, with the mark that they reached the account. */
function KeptArtwork() {
	return (
		<svg
			viewBox="40 20 580 270"
			preserveAspectRatio="xMidYMid meet"
			style={{ width: "100%", height: "100%", display: "block" }}
		>
			<title>Documents kept in your account, each shown as it looks</title>
			{[0, 1, 2].map((row) => (
				<g key={row} transform={`translate(${70 + row * 14} ${40 + row * 78})`}>
					<rect
						width="360"
						height="62"
						rx="14"
						style={{
							fill: "var(--sf)",
							stroke: "var(--line)",
							strokeWidth: 2,
						}}
					/>
					<rect x="14" y="9" width="34" height="44" rx="5" fill="#FFFFFF" />
					<rect
						x="14"
						y="9"
						width="34"
						height="44"
						rx="5"
						fill="none"
						style={{ stroke: "var(--line)", strokeWidth: 2 }}
					/>
					<rect
						x="20"
						y="17"
						width="22"
						height="5"
						rx="2.5"
						style={{ fill: "var(--p)" }}
					/>
					<rect x="20" y="27" width="22" height="4" rx="2" fill="#C9CDD1" />
					<rect x="20" y="35" width="16" height="4" rx="2" fill="#C9CDD1" />
					<rect
						x="64"
						y="18"
						width={150 - row * 22}
						height="10"
						rx="5"
						style={{ fill: "var(--tx)" }}
					/>
					<rect
						x="64"
						y="37"
						width="96"
						height="7"
						rx="3.5"
						style={{ fill: "var(--mt)", opacity: 0.5 }}
					/>
					<circle cx="326" cy="31" r="13" style={{ fill: "var(--p)" }} />
					<path
						d="M320 31 l4.5 4.5 l8 -9"
						fill="none"
						strokeWidth="3"
						strokeLinecap="round"
						strokeLinejoin="round"
						style={{ stroke: "var(--onp)" }}
					/>
				</g>
			))}
			{/* The account they are kept in */}
			<g transform="translate(470 96)">
				<circle cx="44" cy="52" r="62" style={{ fill: "var(--p)" }} />
				<path
					d="M22 74 a20 20 0 0 1 2 -40 a26 26 0 0 1 50 6 a17 17 0 0 1 -4 34 z"
					style={{ fill: "var(--onp)" }}
				/>
				<path
					d="M36 56 l8 8 l14 -16"
					fill="none"
					strokeWidth="5"
					strokeLinecap="round"
					strokeLinejoin="round"
					style={{ stroke: "var(--p)" }}
				/>
			</g>
		</svg>
	);
}

export function ToolsSection() {
	return (
		<section id="tools" style={{ padding: "0 24px 104px" }}>
			<div
				style={{
					maxWidth: "1240px",
					margin: "0 auto",
					display: "flex",
					flexDirection: "column",
					gap: "48px",
				}}
			>
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
						<span style={eyebrow}>WITH YOUR PHONE ALONE</span>
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
							No printer in reach? The phone still gets it done.
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
						Scan, tidy, convert and lay out documents wherever you are. Print
						them later, on any printer you add.
					</p>
				</div>

				{/* The tools: a picture of them at work, and what each does */}
				<div
					style={{
						display: "grid",
						gridTemplateColumns:
							"repeat(auto-fit, minmax(min(100%, 380px), 1fr))",
						gap: "20px",
					}}
				>
					{/* The picture stands on the page itself, with no card around it. */}
					<div
						style={{
							minHeight: "340px",
							display: "flex",
							alignItems: "center",
						}}
					>
						<EditingArtwork />
					</div>
					<div
						style={{
							display: "grid",
							gridTemplateColumns:
								"repeat(auto-fit, minmax(min(100%, 240px), 1fr))",
							gap: "20px",
						}}
					>
						{tools.map((tool) => (
							<div
								key={tool.title}
								style={{
									...card,
									padding: "22px",
									display: "flex",
									flexDirection: "column",
									gap: "10px",
								}}
							>
								<span
									style={{
										width: "44px",
										height: "44px",
										borderRadius: "var(--rb)",
										background: "var(--p)",
										color: "var(--onp)",
										display: "flex",
										alignItems: "center",
										justifyContent: "center",
										transition: "border-radius 0.2s ease",
									}}
								>
									<Icon name={tool.icon} size={24} />
								</span>
								<span style={{ fontSize: "17px", fontWeight: 700 }}>
									{tool.title}
								</span>
								<span
									style={{
										fontSize: "15px",
										lineHeight: 1.5,
										color: "var(--mt)",
									}}
								>
									{tool.description}
								</span>
							</div>
						))}
					</div>
				</div>

				{/* Where it all goes */}
				<div
					style={{
						...card,
						display: "grid",
						gridTemplateColumns:
							"repeat(auto-fit, minmax(min(100%, 380px), 1fr))",
					}}
				>
					<div
						style={{
							padding: "clamp(28px, 4vw, 48px)",
							display: "flex",
							flexDirection: "column",
							gap: "24px",
						}}
					>
						<div
							style={{ display: "flex", flexDirection: "column", gap: "12px" }}
						>
							<span style={eyebrow}>YOUR DOCUMENTS</span>
							<h3
								style={{
									margin: 0,
									fontSize: "clamp(26px, 3vw, 36px)",
									lineHeight: 1.1,
									letterSpacing: "-0.02em",
									fontWeight: 800,
									textWrap: "balance",
								}}
							>
								Never lose what you just made.
							</h3>
						</div>
						<div style={{ display: "flex", flexDirection: "column" }}>
							{kept.map((point, index) => (
								<div
									key={point.title}
									style={{
										display: "flex",
										gap: "16px",
										padding: "16px 0",
										borderBottom:
											index < kept.length - 1
												? "1px solid var(--line)"
												: "none",
									}}
								>
									<Icon
										name={point.icon}
										size={26}
										style={{ color: "var(--em)", flexShrink: 0 }}
									/>
									<div
										style={{
											display: "flex",
											flexDirection: "column",
											gap: "4px",
										}}
									>
										<span style={{ fontSize: "17px", fontWeight: 700 }}>
											{point.title}
										</span>
										<span
											style={{
												fontSize: "15px",
												lineHeight: 1.5,
												color: "var(--mt)",
											}}
										>
											{point.description}
										</span>
									</div>
								</div>
							))}
						</div>
					</div>
					<div
						style={{
							minHeight: "260px",
							background: "var(--bg)",
							display: "flex",
							alignItems: "center",
							padding: "24px",
						}}
					>
						<KeptArtwork />
					</div>
				</div>
			</div>
		</section>
	);
}
