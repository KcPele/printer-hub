import { unwrap } from "@printerhub/api-client";
import { useMutation } from "@tanstack/react-query";
import { type FormEvent, useState } from "react";
import { api, problemText } from "../../lib/admin/api";
import { adminSession } from "../../lib/admin/session";
import { Icon } from "../landing/icon";
import { Button, Card, Field, Notice } from "./ui";

/** The door to the admin console: an email and a password. */
export function SignIn() {
	const [email, setEmail] = useState("");
	const [password, setPassword] = useState("");

	const signIn = useMutation({
		mutationFn: async () =>
			unwrap(
				await api.POST("/api/v1/auth/login", { body: { email, password } }),
			),
		onSuccess: ({ tokens }) => adminSession.save(tokens),
	});

	const submit = (event: FormEvent) => {
		event.preventDefault();
		signIn.mutate();
	};

	return (
		<main className="flex min-h-screen items-center justify-center p-4">
			<Card className="w-full max-w-sm">
				<div className="mb-5 flex items-center gap-3">
					<div className="flex h-10 w-10 items-center justify-center rounded-[var(--rb)] bg-[var(--p)] text-[var(--onp)]">
						<Icon name="print" size={24} filled />
					</div>
					<div>
						<h1 className="m-0 text-lg font-extrabold">PrinterHub admin</h1>
						<p className="m-0 text-xs text-[var(--mt)]">
							For PrinterHub's own staff
						</p>
					</div>
				</div>
				<form onSubmit={submit} className="flex flex-col gap-3">
					<Field
						label="Email"
						type="email"
						autoComplete="username"
						required
						value={email}
						onChange={(event) => setEmail(event.target.value)}
					/>
					<Field
						label="Password"
						type="password"
						autoComplete="current-password"
						required
						value={password}
						onChange={(event) => setPassword(event.target.value)}
					/>
					{signIn.isError ? <Notice>{problemText(signIn.error)}</Notice> : null}
					<Button tone="primary" type="submit" busy={signIn.isPending}>
						Sign in
					</Button>
				</form>
			</Card>
		</main>
	);
}
