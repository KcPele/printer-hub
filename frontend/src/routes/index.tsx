import { createFileRoute } from "@tanstack/react-router";
import { LandingPage } from "../components/landing/landing-page";
import {
	SHARE_IMAGE,
	SITE_DESCRIPTION,
	SITE_NAME,
	SITE_TITLE,
	SITE_URL,
} from "../lib/site";

const SHARE_IMAGE_ALT =
	"PrinterHub: print, scan and copy from your phone. Find a printer, tap it, use it.";

export const Route = createFileRoute("/")({
	head: () => ({
		meta: [
			{ title: SITE_TITLE },
			{ name: "description", content: SITE_DESCRIPTION },
			{
				name: "robots",
				content: "index, follow, max-image-preview:large",
			},
			// How a link to the page looks where it is shared.
			{ property: "og:type", content: "website" },
			{ property: "og:url", content: `${SITE_URL}/` },
			{ property: "og:title", content: SITE_TITLE },
			{ property: "og:description", content: SITE_DESCRIPTION },
			{ property: "og:image", content: SHARE_IMAGE },
			{ property: "og:image:width", content: "1200" },
			{ property: "og:image:height", content: "630" },
			{ property: "og:image:alt", content: SHARE_IMAGE_ALT },
			{ property: "og:locale", content: "en_US" },
			{ name: "twitter:card", content: "summary_large_image" },
			{ name: "twitter:title", content: SITE_TITLE },
			{ name: "twitter:description", content: SITE_DESCRIPTION },
			{ name: "twitter:image", content: SHARE_IMAGE },
			{ name: "twitter:image:alt", content: SHARE_IMAGE_ALT },
		],
		links: [{ rel: "canonical", href: `${SITE_URL}/` }],
		// What the page is about, for a search engine: the site, who makes
		// it, and the app. Nothing here that the page does not say: no
		// price, rating, or store link until there is one.
		scripts: [
			{
				type: "application/ld+json",
				children: JSON.stringify({
					"@context": "https://schema.org",
					"@graph": [
						{
							"@type": "WebSite",
							"@id": `${SITE_URL}/#website`,
							url: `${SITE_URL}/`,
							name: SITE_NAME,
							description: SITE_DESCRIPTION,
							inLanguage: "en",
						},
						{
							"@type": "Organization",
							"@id": `${SITE_URL}/#organization`,
							name: SITE_NAME,
							url: `${SITE_URL}/`,
							logo: `${SITE_URL}/icon-512.png`,
						},
						{
							"@type": "SoftwareApplication",
							"@id": `${SITE_URL}/#app`,
							name: SITE_NAME,
							description: SITE_DESCRIPTION,
							applicationCategory: "UtilitiesApplication",
							operatingSystem: "Android, iOS",
							url: `${SITE_URL}/`,
							image: SHARE_IMAGE,
							publisher: { "@id": `${SITE_URL}/#organization` },
						},
					],
				}),
			},
		],
	}),
	component: LandingPage,
});
