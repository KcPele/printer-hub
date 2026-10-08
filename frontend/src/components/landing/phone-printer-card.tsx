export function PhonePrinterGraphic() {
	return (
		<div
			style={{
				display: "flex",
				justifyContent: "center",
				padding: "4px 0 2px",
			}}
		>
			<div style={{ position: "relative", width: "120px", height: "92px" }}>
				<div
					style={{
						position: "absolute",
						top: 0,
						left: "8px",
						right: "8px",
						height: "15px",
						background: "#F3F3F3",
						border: "1px solid #D6D6D6",
						borderRadius: "6px 6px 2px 2px",
					}}
				/>
				<div
					style={{
						position: "absolute",
						top: "14px",
						left: 0,
						right: 0,
						height: "62px",
						background: "#FFFFFF",
						border: "1px solid #D6D6D6",
						borderRadius: "8px",
					}}
				/>
				<div
					style={{
						position: "absolute",
						top: "21px",
						right: "10px",
						width: "34px",
						height: "12px",
						background: "var(--inv)",
						borderRadius: "3px",
					}}
				/>
				<div
					style={{
						position: "absolute",
						top: "25px",
						right: "14px",
						width: "5px",
						height: "5px",
						borderRadius: "999px",
						background: "var(--p)",
					}}
				/>
				<div
					style={{
						position: "absolute",
						top: "39px",
						left: "1px",
						right: "1px",
						height: "3px",
						background: "var(--p)",
					}}
				/>
				<div
					style={{
						position: "absolute",
						top: "44px",
						left: "30px",
						right: "30px",
						height: "14px",
						background: "#FFFFFF",
						border: "1px solid #E2E2E2",
						borderRadius: "1px",
					}}
				/>
				<div
					style={{
						position: "absolute",
						top: "56px",
						left: "16px",
						right: "16px",
						height: "6px",
						background: "#2A2A2A",
						borderRadius: "3px",
					}}
				/>
				<div
					style={{
						position: "absolute",
						bottom: 0,
						left: "5px",
						right: "5px",
						height: "17px",
						background: "#EDEDED",
						border: "1px solid #D6D6D6",
						borderRadius: "0 0 8px 8px",
					}}
				/>
			</div>
		</div>
	);
}

export function PhoneTonerGauges() {
	return (
		<div
			style={{
				display: "grid",
				gridTemplateColumns: "repeat(4, 1fr)",
				gap: "6px",
			}}
		>
			<div style={{ display: "flex", flexDirection: "column", gap: "3px" }}>
				<div
					style={{
						height: "4px",
						borderRadius: "999px",
						background: "#E4E4E4",
						overflow: "hidden",
					}}
				>
					<div
						style={{ width: "78%", height: "100%", background: "#00A3E0" }}
					/>
				</div>
				<span style={{ fontSize: "9px", color: "var(--mt)" }}>C 78%</span>
			</div>
			<div style={{ display: "flex", flexDirection: "column", gap: "3px" }}>
				<div
					style={{
						height: "4px",
						borderRadius: "999px",
						background: "#E4E4E4",
						overflow: "hidden",
					}}
				>
					<div
						style={{ width: "54%", height: "100%", background: "#D6338A" }}
					/>
				</div>
				<span style={{ fontSize: "9px", color: "var(--mt)" }}>M 54%</span>
			</div>
			<div style={{ display: "flex", flexDirection: "column", gap: "3px" }}>
				<div
					style={{
						height: "4px",
						borderRadius: "999px",
						background: "#E4E4E4",
						overflow: "hidden",
					}}
				>
					<div
						style={{ width: "17%", height: "100%", background: "#E8B800" }}
					/>
				</div>
				<span style={{ fontSize: "9px", color: "#A15C00", fontWeight: 700 }}>
					Y 17%
				</span>
			</div>
			<div style={{ display: "flex", flexDirection: "column", gap: "3px" }}>
				<div
					style={{
						height: "4px",
						borderRadius: "999px",
						background: "#E4E4E4",
						overflow: "hidden",
					}}
				>
					<div
						style={{ width: "91%", height: "100%", background: "#2A2A2A" }}
					/>
				</div>
				<span style={{ fontSize: "9px", color: "var(--mt)" }}>K 91%</span>
			</div>
		</div>
	);
}
