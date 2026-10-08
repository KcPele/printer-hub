import { unwrap } from "@printerhub/api-client";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { type FormEvent, useState } from "react";
import {
	adminKeys,
	api,
	type FeatureFlag,
	problemText,
} from "../../lib/admin/api";
import {
	Button,
	Card,
	ConfirmButton,
	Field,
	Notice,
	PageTitle,
	Select,
	Switch,
} from "./ui";

const KEY_PATTERN = "^[a-z][a-z0-9_]{1,99}$";

/**
 * The feature switches: what is on for everyone, and what is set
 * differently for one workspace. The apps ask which are on as they start.
 */
export function FeatureSwitches() {
	const [adding, setAdding] = useState(false);
	const flags = useQuery({
		queryKey: adminKeys.flags,
		queryFn: async () => unwrap(await api.GET("/api/v1/admin/feature-flags")),
	});

	return (
		<>
			<PageTitle
				title="Feature switches"
				lead="A switch is on or off for every workspace, unless a workspace is set differently below it. An app treats a switch it has not heard of as off."
				action={
					<Button
						tone="primary"
						icon="add"
						onClick={() => setAdding((open) => !open)}
					>
						New switch
					</Button>
				}
			/>
			{adding ? <NewSwitch onDone={() => setAdding(false)} /> : null}
			{flags.isError ? <Notice>{problemText(flags.error)}</Notice> : null}
			{flags.isPending ? (
				<p className="text-sm text-[var(--mt)]">Loading the switches…</p>
			) : null}
			{flags.data?.length === 0 ? (
				<Card>
					<p className="m-0 text-sm text-[var(--mt)]">
						There are no switches yet. Everything an app asks about is off.
					</p>
				</Card>
			) : null}
			<div className="flex flex-col gap-3">
				{flags.data?.map((flag) => (
					<SwitchRow key={flag.key} flag={flag} />
				))}
			</div>
		</>
	);
}

/** Saves a switch: a new one, or one whose value or description changed. */
function useSaveSwitch() {
	const queryClient = useQueryClient();
	return useMutation({
		mutationFn: async (flag: {
			key: string;
			description: string;
			enabled: boolean;
		}) =>
			unwrap(
				await api.PUT("/api/v1/admin/feature-flags/{key}", {
					params: { path: { key: flag.key } },
					body: { description: flag.description, enabled: flag.enabled },
				}),
			),
		onSuccess: () =>
			queryClient.invalidateQueries({ queryKey: adminKeys.flags }),
	});
}

function NewSwitch({ onDone }: { onDone: () => void }) {
	const [key, setKey] = useState("");
	const [description, setDescription] = useState("");
	const [enabled, setEnabled] = useState(false);
	const save = useSaveSwitch();

	const submit = (event: FormEvent) => {
		event.preventDefault();
		save.mutate({ key, description, enabled }, { onSuccess: onDone });
	};

	return (
		<Card className="mb-4">
			<form onSubmit={submit} className="flex flex-col gap-3">
				<div className="grid gap-3 md:grid-cols-[1fr_2fr]">
					<Field
						label="Key"
						required
						pattern={KEY_PATTERN}
						placeholder="scan_to_email"
						hint="Small letters, digits, and underscores. The apps ask for it by this name, so it cannot be changed later."
						value={key}
						onChange={(event) => setKey(event.target.value)}
					/>
					<Field
						label="What it switches"
						maxLength={500}
						value={description}
						onChange={(event) => setDescription(event.target.value)}
					/>
				</div>
				<div className="flex items-center gap-3 text-sm">
					<Switch
						on={enabled}
						label="On for every workspace"
						onChange={setEnabled}
					/>
					<span>
						{enabled ? "On for every workspace" : "Off for every workspace"}
					</span>
				</div>
				{save.isError ? <Notice>{problemText(save.error)}</Notice> : null}
				<div className="flex gap-2">
					<Button tone="primary" type="submit" busy={save.isPending}>
						Add the switch
					</Button>
					<Button tone="quiet" onClick={onDone}>
						Cancel
					</Button>
				</div>
			</form>
		</Card>
	);
}

function SwitchRow({ flag }: { flag: FeatureFlag }) {
	const queryClient = useQueryClient();
	const [open, setOpen] = useState(false);
	const [description, setDescription] = useState(flag.description);
	const save = useSaveSwitch();
	const remove = useMutation({
		mutationFn: async () =>
			unwrap(
				await api.DELETE("/api/v1/admin/feature-flags/{key}", {
					params: { path: { key: flag.key } },
				}),
			),
		onSuccess: () =>
			queryClient.invalidateQueries({ queryKey: adminKeys.flags }),
	});
	const failed = save.error ?? remove.error;

	return (
		<Card>
			<div className="flex flex-wrap items-center gap-4">
				<Switch
					on={flag.enabled}
					label={`${flag.key}, for every workspace`}
					disabled={save.isPending}
					onChange={(enabled) =>
						save.mutate({
							key: flag.key,
							description: flag.description,
							enabled,
						})
					}
				/>
				<div className="min-w-0 flex-1">
					<p className="m-0 break-all font-mono text-sm font-semibold">
						{flag.key}
					</p>
					<p className="m-0 text-sm text-[var(--mt)]">
						{flag.description || "No description."}
					</p>
				</div>
				<span className="basis-full text-xs text-[var(--mt)] sm:basis-auto">
					{flag.enabled ? "On" : "Off"} for everyone
					{flag.overrides.length > 0
						? ` · ${flag.overrides.length} set differently`
						: ""}
				</span>
				<Button
					className="w-full sm:w-auto"
					icon={open ? "expand_less" : "expand_more"}
					aria-expanded={open}
					onClick={() => setOpen((shown) => !shown)}
				>
					{open ? "Close" : "Change"}
				</Button>
			</div>
			{failed ? (
				<div className="mt-3">
					<Notice>{problemText(failed)}</Notice>
				</div>
			) : null}
			{open ? (
				<div
					className="mt-4 flex flex-col gap-5 pt-4"
					style={{ borderTop: "1px solid var(--line)" }}
				>
					<form
						className="flex flex-wrap items-end gap-2"
						onSubmit={(event) => {
							event.preventDefault();
							save.mutate({
								key: flag.key,
								description,
								enabled: flag.enabled,
							});
						}}
					>
						<Field
							label="What it switches"
							maxLength={500}
							className="basis-full sm:basis-64 sm:flex-1"
							value={description}
							onChange={(event) => setDescription(event.target.value)}
						/>
						<Button
							type="submit"
							busy={save.isPending}
							disabled={description === flag.description}
						>
							Save the description
						</Button>
					</form>
					<Overrides flag={flag} />
					<div>
						<ConfirmButton
							label="Delete"
							question={`Delete ${flag.key}? Every app will take it as off.`}
							busy={remove.isPending}
							onConfirm={() => remove.mutate()}
						/>
					</div>
				</div>
			) : null}
		</Card>
	);
}

/** The workspaces a switch is set for by name, whatever it is for the rest. */
function Overrides({ flag }: { flag: FeatureFlag }) {
	const queryClient = useQueryClient();
	const [workspace, setWorkspace] = useState("");
	const [value, setValue] = useState(flag.enabled ? "off" : "on");
	// The workspaces this administrator belongs to, to save typing their IDs.
	const mine = useQuery({
		queryKey: adminKeys.workspaces,
		queryFn: async () => unwrap(await api.GET("/api/v1/organizations")),
	});
	const names = new Map(
		(mine.data ?? []).map((organization) => [
			organization.id,
			organization.name,
		]),
	);
	const done = () =>
		queryClient.invalidateQueries({ queryKey: adminKeys.flags });

	const set = useMutation({
		mutationFn: async (override: {
			organizationId: string;
			enabled: boolean;
		}) =>
			unwrap(
				await api.PUT(
					"/api/v1/admin/feature-flags/{key}/overrides/{organization_id}",
					{
						params: {
							path: {
								key: flag.key,
								organization_id: override.organizationId,
							},
						},
						body: { enabled: override.enabled },
					},
				),
			),
		onSuccess: () => {
			setWorkspace("");
			return done();
		},
	});
	const clear = useMutation({
		mutationFn: async (organizationId: string) =>
			unwrap(
				await api.DELETE(
					"/api/v1/admin/feature-flags/{key}/overrides/{organization_id}",
					{
						params: {
							path: { key: flag.key, organization_id: organizationId },
						},
					},
				),
			),
		onSuccess: done,
	});
	const failed = set.error ?? clear.error;
	const listId = `workspaces-${flag.key}`;

	return (
		<div className="flex flex-col gap-3">
			<h3 className="m-0 text-sm font-extrabold">Set for one workspace</h3>
			{flag.overrides.length === 0 ? (
				<p className="m-0 text-sm text-[var(--mt)]">
					No workspace is set differently.
				</p>
			) : (
				<ul className="m-0 flex list-none flex-col gap-2 p-0">
					{flag.overrides.map((override) => (
						<li
							key={override.organization_id}
							className="flex flex-wrap items-center gap-3 text-sm"
						>
							<Switch
								on={override.enabled}
								label={`${flag.key} for workspace ${override.organization_id}`}
								disabled={set.isPending}
								onChange={(enabled) =>
									set.mutate({
										organizationId: override.organization_id,
										enabled,
									})
								}
							/>
							<span className="min-w-0 flex-1 basis-[calc(100%-4rem)] break-all sm:basis-auto">
								{names.get(override.organization_id) ? (
									<span className="font-bold">
										{names.get(override.organization_id)}{" "}
									</span>
								) : null}
								<span className="font-mono text-xs text-[var(--mt)]">
									{override.organization_id}
								</span>
							</span>
							<span className="text-xs text-[var(--mt)]">
								{override.enabled ? "On" : "Off"} here
							</span>
							<Button
								tone="quiet"
								busy={clear.isPending}
								onClick={() => clear.mutate(override.organization_id)}
							>
								Back to the rest
							</Button>
						</li>
					))}
				</ul>
			)}
			<form
				className="flex flex-wrap items-end gap-2"
				onSubmit={(event) => {
					event.preventDefault();
					set.mutate({
						organizationId: workspace.trim(),
						enabled: value === "on",
					});
				}}
			>
				<Field
					label="Workspace ID"
					required
					list={listId}
					pattern="^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
					placeholder="0198c0de-0000-7000-8000-00000000000b"
					className="basis-full sm:basis-72 sm:flex-1"
					value={workspace}
					onChange={(event) => setWorkspace(event.target.value)}
				/>
				<datalist id={listId}>
					{(mine.data ?? []).map((organization) => (
						<option key={organization.id} value={organization.id}>
							{organization.name}
						</option>
					))}
				</datalist>
				<Select
					label="Set it"
					value={value}
					options={{ on: "On", off: "Off" }}
					onChange={setValue}
				/>
				<Button type="submit" busy={set.isPending}>
					Set for this workspace
				</Button>
			</form>
			{failed ? <Notice>{problemText(failed)}</Notice> : null}
		</div>
	);
}
