/**
 * What search engines and link previews are told about the site. One place,
 * so the landing page, the sitemap, and the share image agree.
 */

/** Where the site lives. `public/robots.txt` and `public/sitemap.xml` name it too. */
export const SITE_URL: string = (
	import.meta.env.VITE_SITE_URL || "https://printerhub.kcpele.com"
).replace(/\/+$/, "");

export const SITE_NAME = "PrinterHub";

export const SITE_TITLE = "PrinterHub — Mobile Printing, Scanning & Copying";

export const SITE_DESCRIPTION =
	"PrinterHub finds the printers around you, works out what each one can do, and picks a connection that works. Printing, scanning and copying take one tap, not a networking lesson.";

/** The picture a link to the site unfurls with: 1200 by 630. */
export const SHARE_IMAGE = `${SITE_URL}/og-image.png`;
