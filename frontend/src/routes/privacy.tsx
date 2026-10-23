import { createFileRoute } from "@tanstack/react-router";
import { LegalPage, LegalSection } from "../components/legal/legal-page";
import { CONTACT_EMAIL, POLICY_UPDATED, SITE_URL } from "../lib/site";

export const Route = createFileRoute("/privacy")({
	head: () => ({
		meta: [
			{ title: "Privacy policy · PrinterHub" },
			{
				name: "description",
				content:
					"What PrinterHub collects, why, where it is kept, and how to have it deleted.",
			},
		],
		links: [{ rel: "canonical", href: `${SITE_URL}/privacy` }],
	}),
	component: PrivacyPage,
});

function PrivacyPage() {
	const mail = `mailto:${CONTACT_EMAIL}`;
	return (
		<LegalPage
			title="Privacy policy"
			lead={`How the PrinterHub app and website handle your information. Last updated ${POLICY_UPDATED}.`}
		>
			<LegalSection title="In short">
				<ul>
					<li>
						Printing and scanning happen between your phone and the printer, on
						your own network. Your pages do not pass through our servers to
						reach a printer.
					</li>
					<li>
						Documents you make in the app are kept in your account so you can
						find them again on any phone. Only you can see them until you share
						one with your workspace.
					</li>
					<li>
						We do not sell your information, show you adverts, or use your
						documents to train anything.
					</li>
					<li>You can delete your account, and what is in it, at any time.</li>
				</ul>
			</LegalSection>

			<LegalSection title="What we collect">
				<p>
					<strong>Your account.</strong> Your name, your email address and a
					password, kept only as a one-way hash we cannot read back. We also
					keep which workspaces you belong to and your role in each.
				</p>
				<p>
					<strong>Your documents.</strong> Scans and files the app makes (PDFs
					and pictures) are copied to your account: the file, its name, its
					size, when it was made, which tool or printer made it, and, where your
					workspace has it switched on, the words read from it so it can be
					searched. The words are read on your phone, not by us.
				</p>
				<p>
					<strong>Your printers and jobs.</strong> The printers added to your
					workspace (their name, model, network address and what they can do)
					and a history of print, scan and copy jobs: what was sent, to which
					printer, when, and how it went. Printer passwords you save are kept
					encrypted and never sent back to any screen.
				</p>
				<p>
					<strong>Your devices.</strong> For each phone you sign in on, its name
					and model, and a token that lets us send it notifications.
				</p>
				<p>
					<strong>Messages to you.</strong> Notifications we have sent you, and
					whether you have read them.
				</p>
			</LegalSection>

			<LegalSection title="What stays on your phone">
				<ul>
					<li>
						<strong>Your signature.</strong> Drawn or taken from a photo, it is
						kept in your phone's secure storage and never sent to us. It leaves
						your phone only as part of a document you save.
					</li>
					<li>
						<strong>Passwords you put on a PDF.</strong> They are used once to
						lock the file and kept nowhere.
					</li>
					<li>
						<strong>Your theme, text size and similar choices.</strong>
					</li>
				</ul>
			</LegalSection>

			<LegalSection title="What the app asks your phone for, and why">
				<ul>
					<li>
						<strong>Camera</strong>: to scan pages and read QR codes, only when
						you choose to.
					</li>
					<li>
						<strong>Photos and files</strong>: to print, sign, convert or join
						the ones you pick. The app sees only what you choose.
					</li>
					<li>
						<strong>Local network, nearby devices and Wi-Fi</strong>: to find
						printers around you and talk to them directly.
					</li>
					<li>
						<strong>Bluetooth and NFC</strong>: to find a printer by touch or
						nearby radio. The document itself always travels over your network.
					</li>
					<li>
						<strong>Location</strong>: asked only on older Android versions,
						which require it to look for Bluetooth printers. We never record
						where you are.
					</li>
					<li>
						<strong>Notifications</strong>: to tell you when a job finishes or
						fails, or when someone invites you to a workspace.
					</li>
				</ul>
			</LegalSection>

			<LegalSection title="Why we use it">
				<p>
					Only to run the service you asked for: to sign you in, keep your
					documents and history, show your workspace its printers, and tell you
					what happened to a job. Email is used for sign-in codes, password
					resets and invitations, not for marketing.
				</p>
			</LegalSection>

			<LegalSection title="Who else handles it">
				<p>
					We use a small number of providers to run the service, each only for
					that purpose:
				</p>
				<ul>
					<li>our hosting provider, which runs our servers and database;</li>
					<li>a file storage service, which holds the documents you keep;</li>
					<li>
						Google Firebase Cloud Messaging, which delivers notifications to
						your phone;
					</li>
					<li>an email service, which delivers the emails described above.</li>
				</ul>
				<p>
					Within a workspace, other members can see the printers, the job
					history and any document you have shared with them. Workspace owners
					and admins can also see who did what, in the workspace's activity log.
				</p>
				<p>We share information beyond this only if the law requires us to.</p>
			</LegalSection>

			<LegalSection title="How it is protected">
				<p>
					Everything travels encrypted (HTTPS). Files are fetched through
					short-lived links that work only for you. Printer passwords are
					encrypted when stored, and your account password is never stored at
					all, only a hash of it.
				</p>
			</LegalSection>

			<LegalSection title="How long we keep it">
				<p>
					For as long as you have an account. A workspace may set documents to
					be removed automatically after a number of days. When you delete your
					account, everything listed under "What we collect" that is yours is
					removed, as described on the{" "}
					<a href="/delete-account">account deletion page</a>.
				</p>
			</LegalSection>

			<LegalSection title="Your choices">
				<ul>
					<li>
						See, rename, share or delete any document in the app, under
						Activity.
					</li>
					<li>Change your name and password in Settings.</li>
					<li>
						Delete your account in the app, or by writing to us: see{" "}
						<a href="/delete-account">Delete your account</a>.
					</li>
					<li>
						Ask us for a copy of your information, or to correct it, at{" "}
						<a href={mail}>{CONTACT_EMAIL}</a>.
					</li>
				</ul>
			</LegalSection>

			<LegalSection title="Children">
				<p>
					PrinterHub is not meant for children under 13, and we do not knowingly
					collect information from them.
				</p>
			</LegalSection>

			<LegalSection title="Changes">
				<p>
					If this policy changes, the new version is posted here with a new
					date. If a change matters, we tell you in the app first.
				</p>
			</LegalSection>

			<LegalSection title="Contact">
				<p>
					Questions about your privacy: <a href={mail}>{CONTACT_EMAIL}</a>.
				</p>
			</LegalSection>
		</LegalPage>
	);
}
