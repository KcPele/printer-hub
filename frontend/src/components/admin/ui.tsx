import {
	type ButtonHTMLAttributes,
	type InputHTMLAttributes,
	type ReactNode,
	type TextareaHTMLAttributes,
	useId,
	useState,
} from "react";
import { Icon } from "../landing/icon";

/*
 * The few building blocks the admin console is made of. They take their
 * colour, shape, and type from the same theme tokens as the landing page.
 */

type Tone = "primary" | "outline" | "danger" | "quiet";

const TONES: Record<Tone, string> = {
	primary: "bg-[var(--p)] text-[var(--onp)] border-transparent",
	outline: "bg-[var(--bg)] text-[var(--tx)] border-[var(--line)]",
	danger: "bg-[var(--bg)] text-[#B3261E] border-[#F0C6C2]",
	quiet: "bg-transparent text-[var(--em)] border-transparent",
};

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
	tone?: Tone;
	icon?: string;
	busy?: boolean;
}

export function Button({
	tone = "outline",
	icon,
	busy = false,
	disabled,
	className = "",
	children,
	type = "button",
	...rest
}: ButtonProps) {
	return (
		<button
			type={type}
			disabled={disabled || busy}
			className={`inline-flex min-h-10 items-center justify-center gap-2 rounded-[var(--rb)] border px-4 py-2 text-sm font-bold whitespace-nowrap cursor-pointer disabled:cursor-not-allowed disabled:opacity-50 ${TONES[tone]} ${className}`}
			{...rest}
		>
			{icon ? (
				<Icon name={busy ? "progress_activity" : icon} size={18} />
			) : null}
			{children}
		</button>
	);
}

interface FieldProps extends InputHTMLAttributes<HTMLInputElement> {
	label: string;
	hint?: string;
}

// 16px type on a phone: anything smaller and iOS zooms the page when a
// field is tapped.
const CONTROL =
	"w-full min-w-0 rounded-[var(--rb)] border border-[var(--line)] bg-[var(--bg)] px-3 py-2 text-base text-[var(--tx)] outline-none focus:border-[var(--em)] sm:text-sm";

export function Field({ label, hint, className = "", ...rest }: FieldProps) {
	const id = useId();
	return (
		<div className={`flex flex-col gap-1 ${className}`}>
			<label htmlFor={id} className="text-xs font-bold text-[var(--mt)]">
				{label}
			</label>
			<input id={id} className={CONTROL} {...rest} />
			{hint ? <p className="m-0 text-xs text-[var(--mt)]">{hint}</p> : null}
		</div>
	);
}

interface AreaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
	label: string;
	hint?: string;
	mono?: boolean;
}

export function Area({
	label,
	hint,
	mono = false,
	className = "",
	...rest
}: AreaProps) {
	const id = useId();
	return (
		<div className={`flex flex-col gap-1 ${className}`}>
			<label htmlFor={id} className="text-xs font-bold text-[var(--mt)]">
				{label}
			</label>
			<textarea
				id={id}
				spellCheck={!mono}
				className={`${CONTROL} ${mono ? "font-mono sm:text-xs" : ""}`}
				{...rest}
			/>
			{hint ? <p className="m-0 text-xs text-[var(--mt)]">{hint}</p> : null}
		</div>
	);
}

interface SelectProps {
	label: string;
	value: string;
	options: Record<string, string>;
	onChange: (value: string) => void;
	className?: string;
}

export function Select({
	label,
	value,
	options,
	onChange,
	className = "",
}: SelectProps) {
	const id = useId();
	return (
		<div className={`flex flex-col gap-1 ${className}`}>
			<label htmlFor={id} className="text-xs font-bold text-[var(--mt)]">
				{label}
			</label>
			<select
				id={id}
				value={value}
				onChange={(event) => onChange(event.target.value)}
				className={CONTROL}
			>
				{Object.entries(options).map(([option, name]) => (
					<option key={option} value={option}>
						{name}
					</option>
				))}
			</select>
		</div>
	);
}

interface SwitchProps {
	on: boolean;
	label: string;
	disabled?: boolean;
	onChange: (on: boolean) => void;
}

/** An on/off switch. Its label is read out, and shown beside it by the caller. */
export function Switch({ on, label, disabled, onChange }: SwitchProps) {
	return (
		<button
			type="button"
			role="switch"
			aria-checked={on}
			aria-label={label}
			disabled={disabled}
			onClick={() => onChange(!on)}
			className={`relative h-7 w-12 shrink-0 cursor-pointer rounded-full border transition-colors disabled:cursor-not-allowed disabled:opacity-50 ${
				on
					? "border-transparent bg-[var(--p)]"
					: "border-[var(--line)] bg-[var(--sf)]"
			}`}
		>
			<span
				className={`absolute top-1 h-[18px] w-[18px] rounded-full transition-all ${
					on ? "left-6 bg-[var(--onp)]" : "left-1 bg-[var(--mt)]"
				}`}
			/>
		</button>
	);
}

export function Card({
	children,
	className = "",
}: {
	children: ReactNode;
	className?: string;
}) {
	return (
		<section
			className={`min-w-0 rounded-[var(--rc)] bg-[var(--sf)] p-4 sm:p-5 ${className}`}
			style={{ border: "var(--bd)" }}
		>
			{children}
		</section>
	);
}

export function Notice({
	children,
	tone = "error",
}: {
	children: ReactNode;
	tone?: "error" | "info";
}) {
	const error = tone === "error";
	return (
		<p
			role={error ? "alert" : "status"}
			className={`m-0 flex items-start gap-2 rounded-[var(--rb)] px-3 py-2 text-sm ${
				error ? "bg-[#FCECEA] text-[#8C1D18]" : "bg-[#E5EDFB] text-[#1D4FB8]"
			}`}
		>
			<Icon name={error ? "error" : "info"} size={18} />
			<span>{children}</span>
		</p>
	);
}

export function PageTitle({
	title,
	lead,
	action,
}: {
	title: string;
	lead: string;
	action?: ReactNode;
}) {
	return (
		<div className="mb-6 flex flex-wrap items-end justify-between gap-4">
			<div className="min-w-0">
				<h1 className="m-0 text-xl font-extrabold tracking-tight sm:text-2xl">
					{title}
				</h1>
				<p className="m-0 mt-1 max-w-2xl text-sm text-[var(--mt)]">{lead}</p>
			</div>
			{action}
		</div>
	);
}

/** A button that asks once more before doing something that cannot be undone. */
export function ConfirmButton({
	label,
	question,
	busy,
	onConfirm,
}: {
	label: string;
	question: string;
	busy?: boolean;
	onConfirm: () => void;
}) {
	const [asking, setAsking] = useState(false);
	if (!asking) {
		return (
			<Button tone="danger" icon="delete" onClick={() => setAsking(true)}>
				{label}
			</Button>
		);
	}
	return (
		<span className="inline-flex flex-wrap items-center gap-2 text-sm">
			<span className="font-bold">{question}</span>
			<Button
				tone="danger"
				busy={busy}
				onClick={() => {
					setAsking(false);
					onConfirm();
				}}
			>
				Yes, {label.toLowerCase()}
			</Button>
			<Button tone="quiet" onClick={() => setAsking(false)}>
				Keep it
			</Button>
		</span>
	);
}
