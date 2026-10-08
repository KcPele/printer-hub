import { unwrap } from "@printerhub/api-client";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { type FormEvent, useState } from "react";
import {
	adminKeys,
	api,
	type PrinterFamily,
	type PrinterFamilyWrite,
	problemText,
} from "../../lib/admin/api";
import {
	Area,
	Button,
	Card,
	ConfirmButton,
	Field,
	Notice,
	PageTitle,
	Select,
} from "./ui";

const CATEGORIES: Record<PrinterFamilyWrite["category"] & string, string> = {
	office_multifunction: "Office multifunction",
	office_printer: "Office printer",
	home_multifunction: "Home multifunction",
	home_printer: "Home printer",
};

/** What a family that says nothing yet is taken to be able to do. */
const BLANK_CAPABILITIES = {
	schema_version: 1,
	print: { supported: true },
	scan: { supported: false },
	copy: { supported: false },
	status: {},
	connectivity: {},
	protocols: {},
};

/**
 * The catalogue of printer families: what the app expects of a printer it
 * finds, before it has asked the printer itself, and what it tells the
 * person setting one up.
 */
export function PrinterFamilies() {
	// The family being changed: one of the list, a new one, or none.
	const [editing, setEditing] = useState<PrinterFamily | "new" | null>(null);
	const families = useQuery({
		queryKey: adminKeys.families,
		queryFn: async () => unwrap(await api.GET("/api/v1/capability-profiles")),
	});

	return (
		<>
			<PageTitle
				title="Printer families"
				lead="A family is matched to a printer by its model name. The app shows these in the catalogue, most popular first, and starts from what a family says until the printer answers for itself."
				action={
					<Button tone="primary" icon="add" onClick={() => setEditing("new")}>
						New family
					</Button>
				}
			/>
			{editing === "new" ? (
				<FamilyEditor family={null} onDone={() => setEditing(null)} />
			) : null}
			{families.isError ? <Notice>{problemText(families.error)}</Notice> : null}
			{families.isPending ? (
				<p className="text-sm text-[var(--mt)]">Loading the catalogue…</p>
			) : null}
			{families.data?.length === 0 ? (
				<Card>
					<p className="m-0 text-sm text-[var(--mt)]">
						The catalogue is empty. The app will ask every printer what it can
						do, and have nothing to say before it answers.
					</p>
				</Card>
			) : null}
			<div className="flex flex-col gap-3">
				{families.data?.map((family) =>
					editing !== "new" && editing?.id === family.id ? (
						<FamilyEditor
							key={family.id}
							family={family}
							onDone={() => setEditing(null)}
						/>
					) : (
						<FamilyRow
							key={family.id}
							family={family}
							onEdit={() => setEditing(family)}
						/>
					),
				)}
			</div>
		</>
	);
}

function FamilyRow({
	family,
	onEdit,
}: {
	family: PrinterFamily;
	onEdit: () => void;
}) {
	const queryClient = useQueryClient();
	const remove = useMutation({
		mutationFn: async () =>
			unwrap(
				await api.DELETE("/api/v1/admin/capability-profiles/{profile_id}", {
					params: { path: { profile_id: family.id } },
				}),
			),
		onSuccess: () =>
			queryClient.invalidateQueries({ queryKey: adminKeys.families }),
	});
	const does = [
		family.capabilities.print?.supported ? "prints" : null,
		family.capabilities.scan?.supported ? "scans" : null,
		family.capabilities.copy?.supported ? "copies" : null,
	].filter(Boolean);

	return (
		<Card>
			{/* On a phone the family takes the card's width, and what can be
			    done to it goes below. */}
			<div className="flex flex-wrap items-start gap-4">
				<div className="min-w-0 basis-full sm:flex-1 sm:basis-0">
					<p className="m-0 text-xs font-bold text-[var(--mt)]">
						{family.manufacturer} ·{" "}
						{CATEGORIES[family.category ?? "office_multifunction"]}
					</p>
					<p className="m-0 text-lg font-extrabold">{family.display_name}</p>
					{family.summary ? (
						<p className="m-0 text-sm text-[var(--mt)]">{family.summary}</p>
					) : null}
					<p className="m-0 mt-2 text-xs text-[var(--mt)]">
						Matches{" "}
						<span className="break-all font-mono">
							{family.model_patterns.join(", ")}
						</span>
						{does.length > 0 ? ` · ${does.join(", ")}` : ""} · popularity{" "}
						{family.popularity} · version {family.version}
					</p>
				</div>
				<div className="flex flex-wrap items-center gap-2">
					<Button icon="edit" onClick={onEdit}>
						Change
					</Button>
					<ConfirmButton
						label="Delete"
						question={`Delete ${family.display_name}?`}
						busy={remove.isPending}
						onConfirm={() => remove.mutate()}
					/>
				</div>
			</div>
			{remove.isError ? (
				<div className="mt-3">
					<Notice>{problemText(remove.error)}</Notice>
				</div>
			) : null}
		</Card>
	);
}

/** One line of a list a line. Empty lines are left out. */
function lines(text: string): string[] {
	return text
		.split("\n")
		.map((line) => line.trim())
		.filter((line) => line.length > 0);
}

function FamilyEditor({
	family,
	onDone,
}: {
	family: PrinterFamily | null;
	onDone: () => void;
}) {
	const queryClient = useQueryClient();
	const [manufacturer, setManufacturer] = useState(family?.manufacturer ?? "");
	const [displayName, setDisplayName] = useState(family?.display_name ?? "");
	const [category, setCategory] = useState<string>(
		family?.category ?? "office_multifunction",
	);
	const [summary, setSummary] = useState(family?.summary ?? "");
	const [popularity, setPopularity] = useState(String(family?.popularity ?? 0));
	const [patterns, setPatterns] = useState(
		(family?.model_patterns ?? []).join("\n"),
	);
	const [tips, setTips] = useState((family?.setup_tips ?? []).join("\n"));
	const [notes, setNotes] = useState((family?.notes ?? []).join("\n"));
	const [optional, setOptional] = useState(
		(family?.optional_features ?? []).join("\n"),
	);
	const [capabilities, setCapabilities] = useState(
		JSON.stringify(family?.capabilities ?? BLANK_CAPABILITIES, null, 2),
	);
	const [unreadable, setUnreadable] = useState<string | null>(null);

	const save = useMutation({
		mutationFn: async (body: PrinterFamilyWrite) =>
			family
				? unwrap(
						await api.PUT("/api/v1/admin/capability-profiles/{profile_id}", {
							params: { path: { profile_id: family.id } },
							body,
						}),
					)
				: unwrap(await api.POST("/api/v1/admin/capability-profiles", { body })),
		onSuccess: async () => {
			await queryClient.invalidateQueries({ queryKey: adminKeys.families });
			onDone();
		},
	});

	const submit = (event: FormEvent) => {
		event.preventDefault();
		let parsed: PrinterFamilyWrite["capabilities"];
		try {
			parsed = JSON.parse(capabilities);
		} catch (error) {
			setUnreadable(
				`What it can do is not valid JSON: ${error instanceof Error ? error.message : "it could not be read"}`,
			);
			return;
		}
		setUnreadable(null);
		save.mutate({
			manufacturer: manufacturer.trim(),
			display_name: displayName.trim(),
			category: category as PrinterFamilyWrite["category"],
			summary: summary.trim() || null,
			popularity: Number(popularity) || 0,
			model_patterns: lines(patterns),
			capabilities: parsed,
			optional_features: lines(optional),
			notes: lines(notes),
			setup_tips: lines(tips),
		});
	};

	return (
		<Card className="mb-4">
			<form onSubmit={submit} className="flex flex-col gap-4">
				<h2 className="m-0 text-lg font-extrabold">
					{family ? `Change ${family.display_name}` : "New printer family"}
				</h2>
				<div className="grid gap-3 md:grid-cols-2">
					<Field
						label="Maker"
						required
						maxLength={100}
						placeholder="Xerox"
						value={manufacturer}
						onChange={(event) => setManufacturer(event.target.value)}
					/>
					<Field
						label="Name of the family"
						required
						maxLength={200}
						placeholder="VersaLink C7100 series"
						value={displayName}
						onChange={(event) => setDisplayName(event.target.value)}
					/>
					<Select
						label="Kind of machine"
						value={category}
						options={CATEGORIES}
						onChange={setCategory}
					/>
					<Field
						label="Popularity"
						type="number"
						min={0}
						max={1000}
						hint="0 to 1000. Higher is listed first in the catalogue."
						value={popularity}
						onChange={(event) => setPopularity(event.target.value)}
					/>
				</div>
				<Field
					label="One line about it"
					maxLength={200}
					value={summary}
					onChange={(event) => setSummary(event.target.value)}
				/>
				<div className="grid gap-3 md:grid-cols-2">
					<Area
						label="Model names it matches"
						required
						rows={4}
						mono
						placeholder={"VersaLink C71*\nVersaLink C7130"}
						hint="One a line. * stands for anything; capitals do not matter."
						value={patterns}
						onChange={(event) => setPatterns(event.target.value)}
					/>
					<Area
						label="What depends on optional hardware"
						rows={4}
						mono
						placeholder={"connectivity.wifi\nconnectivity.nfc"}
						hint="One a line: a path into what it can do that the app must confirm with the printer."
						value={optional}
						onChange={(event) => setOptional(event.target.value)}
					/>
					<Area
						label="Setting it up, step by step"
						rows={5}
						hint="One step a line, in order, for the person holding the phone."
						value={tips}
						onChange={(event) => setTips(event.target.value)}
					/>
					<Area
						label="Good to know"
						rows={5}
						hint="One note a line."
						value={notes}
						onChange={(event) => setNotes(event.target.value)}
					/>
				</div>
				<Area
					label="What it can do (JSON)"
					required
					rows={16}
					mono
					hint="Print, scan, copy, status, connectivity, and protocols, as the API's PrinterCapabilities. The API says which part it does not accept."
					value={capabilities}
					onChange={(event) => setCapabilities(event.target.value)}
				/>
				{unreadable ? <Notice>{unreadable}</Notice> : null}
				{save.isError ? <Notice>{problemText(save.error)}</Notice> : null}
				<div className="flex gap-2">
					<Button tone="primary" type="submit" busy={save.isPending}>
						{family ? "Save the changes" : "Add the family"}
					</Button>
					<Button tone="quiet" onClick={onDone}>
						Cancel
					</Button>
				</div>
			</form>
		</Card>
	);
}
