import { createFileRoute } from "@tanstack/react-router";
import { LegalPage, LegalSection } from "../components/legal/legal-page";
import { CONTACT_EMAIL, SITE_URL } from "../lib/site";

export const Route = createFileRoute("/delete-account")({
	head: () => ({
		meta: [
			{ title: "Delete your account · PrinterHub" },
			{
				name: "description",
				content:
					"How to delete your PrinterHub account, and what is deleted with it.",
			},
		],
		links: [{ rel: "canonical", href: `${SITE_URL}/delete-account` }],
	}),
	component: DeleteAccountPage,
});

function DeleteAccountPage() {
	const mail = `mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent(
		"Delete my PrinterHub account",
	)}`;
	return (
		<LegalPage
			title="Delete your account"
			lead="You can delete your PrinterHub account, and what is kept in it, whenever you like."
		>
			<LegalSection title="In the app">
				<ol>
					<li>Open PrinterHub and sign in.</li>
					<li>Go to Settings, then Delete account.</li>
					<li>Type your password and confirm.</li>
				</ol>
				<p>
					Your account is deleted at once, and you are signed out on every
					phone.
				</p>
			</LegalSection>

			<LegalSection title="Without the app">
				<p>
					If you no longer have the app, email{" "}
					<a href={mail}>{CONTACT_EMAIL}</a> from the address you signed up
					with, asking us to delete your account. We reply to confirm it is you,
					then delete it within 30 days, and tell you when it is done.
				</p>
			</LegalSection>

			<LegalSection title="What is deleted">
				<ul>
					<li>Your account: your name, email address and password.</li>
					<li>
						Every document you kept, with its files, including any you shared
						with a workspace.
					</li>
					<li>Your phones' notification tokens, and your notifications.</li>
					<li>
						A workspace that only you belong to, with its printers, presets and
						history.
					</li>
				</ul>
			</LegalSection>

			<LegalSection title="What is kept">
				<ul>
					<li>
						In a workspace you share with others, its print and scan history
						stays, as the workspace's record, but no longer shows your name. Its
						activity log notes that a member's account was deleted.
					</li>
					<li>
						Copies in our backups are overwritten in the normal course of
						things, within 30 days.
					</li>
				</ul>
				<p>
					If you are the only owner of a workspace other people use, the app
					asks you first to make someone else an owner, or to delete the
					workspace, so they are not left without one.
				</p>
			</LegalSection>

			<LegalSection title="Signature and phone settings">
				<p>
					Your saved signature and your theme are kept on your phone, never with
					us. Uninstalling the app removes them.
				</p>
			</LegalSection>
		</LegalPage>
	);
}
