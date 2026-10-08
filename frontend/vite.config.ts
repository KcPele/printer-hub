import tailwindcss from "@tailwindcss/vite";
import { devtools } from "@tanstack/devtools-vite";

import { tanstackStart } from "@tanstack/react-start/plugin/vite";

import viteReact from "@vitejs/plugin-react";
import { nitro } from "nitro/vite";
import { defineConfig } from "vite";

const config = defineConfig({
	resolve: {
		// The API client is the shared one in `packages/api-client`, reached
		// through the path in tsconfig.json. Its one dependency is installed
		// here, so it is resolved from here.
		tsconfigPaths: true,
		dedupe: ["openapi-fetch"],
	},
	plugins: [
		devtools(),
		nitro({
			rollupConfig: { external: [/^@sentry\//] },
			// The admin console is drawn in the browser, so a tag in its page
			// would never reach a search engine. The answer itself says it.
			routeRules: {
				"/admin": { headers: { "X-Robots-Tag": "noindex, nofollow" } },
				"/admin/**": { headers: { "X-Robots-Tag": "noindex, nofollow" } },
			},
		}),
		tailwindcss(),
		tanstackStart(),
		viteReact(),
	],
});

export default config;
