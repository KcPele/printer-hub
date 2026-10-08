# PrinterHub web app

The landing page (`/`) and the admin console (`/admin`).

## The admin console

`/admin` is for PrinterHub's own staff. It manages what every app is told: the feature switches, for everyone or for one workspace, and the catalogue of printer families. It uses the eight super-user operations of the API and nothing else special.

Run it against a backend on this machine:

```bash
npm install
npm run dev
```

Then open http://localhost:3000/admin. The backend has to be running (`make infra` and `make dev` from the repository root) and has to allow this origin: `PRINTERHUB_CORS_ORIGINS=["http://localhost:3000"]` in `backend/.env`, which the example file already has.

Only a super-user gets in. Register an account, then, from `backend/`:

```bash
uv run python -m scripts.promote_superuser you@example.com
```

- **Where the API is.** `VITE_API_URL` (see `.env.example`). Without it, `npm run dev` talks to `http://localhost:8000` and a production build to the live backend.
- **The API client is the shared one**, `packages/api-client`, reached through the path in `tsconfig.json`. Types come from the backend's contract, so a request the API would refuse for its shape does not compile. `npm run typecheck` checks it.
- **The Docker image is built from the repository root** for that reason: `docker build -f frontend/Dockerfile .`
- **The sign-in is kept in the tab's session storage.** Closing the tab signs out. Nothing under `/admin` is rendered on the server.

## What search engines and link previews see

- **The landing page is rendered on the server**, so its text, its one `h1`, and its head are in the first answer.
- **`src/lib/site.ts`** holds the site's address, title, and description. `src/routes/index.tsx` turns them into the canonical link, the Open Graph and Twitter tags, and the structured data (the site, the organization, and the app). It claims nothing the page does not say: no price, rating, or store link until there is one. Add the store links there when the app is published.
- **`public/`** has the icons, `og-image.png` (the picture a shared link shows, 1200 by 630), `robots.txt`, `sitemap.xml`, and the web manifest. The icons and the share image are drawn from the phone app's mark by `tool/brand.py`.
- **The admin console is served with `X-Robots-Tag: noindex, nofollow`** (`vite.config.ts`). It is not disallowed in `robots.txt`, because a crawler that may not ask never sees that header.
- A new public page is added to `public/sitemap.xml` and given its own title, description, and canonical link in its route's `head`.

---

What follows came with the project template.

Welcome to your new TanStack Start app!

# Getting Started

To run this application:

```bash
npm install
npm run dev
```

# Building For Production

To build this application for production:

```bash
npm run build
```

## Styling

This project uses [Tailwind CSS](https://tailwindcss.com/) for styling.

### Removing Tailwind CSS

If you prefer not to use Tailwind CSS:

1. Remove the demo pages in `src/routes/demo/`
2. Replace the Tailwind import in `src/styles.css` with your own styles
3. Remove `tailwindcss()` from the plugins array in `vite.config.ts`
4. Remove `@tailwindcss/vite` and `tailwindcss` from `package.json`

## Linting & Formatting

This project uses [Biome](https://biomejs.dev/) for linting and formatting. The following scripts are available:


```bash
npm run lint
npm run format
npm run check
```


## Deploy with Nitro

This project uses Nitro as a generic server adapter, so it can run on any Node-compatible host.

```bash
npm run build
node dist/server/index.mjs
```

The build output is a self-contained Node server. To deploy, push the `dist/` directory to your host (Render, Fly.io, your own VPS, etc.) and run the server command above.

For host-specific presets (Vercel, Netlify, Cloudflare, AWS Lambda, etc.) and tuning, see https://v3.nitro.build/deploy.


## Shadcn

Add components using the latest version of [Shadcn](https://ui.shadcn.com/).

```bash
pnpm dlx shadcn@latest add button
```



## Routing

This project uses [TanStack Router](https://tanstack.com/router) with file-based routing. Routes are managed as files in `src/routes`.

### Adding A Route

To add a new route to your application just add a new file in the `./src/routes` directory.

TanStack will automatically generate the content of the route file for you.

Now that you have two routes you can use a `Link` component to navigate between them.

### Adding Links

To use SPA (Single Page Application) navigation you will need to import the `Link` component from `@tanstack/react-router`.

```tsx
import { Link } from "@tanstack/react-router";
```

Then anywhere in your JSX you can use it like so:

```tsx
<Link to="/about">About</Link>
```

This will create a link that will navigate to the `/about` route.

More information on the `Link` component can be found in the [Link documentation](https://tanstack.com/router/v1/docs/framework/react/api/router/linkComponent).

### Using A Layout

In the File Based Routing setup the layout is located in `src/routes/__root.tsx`. Anything you add to the root route will appear in all the routes. The route content will appear in the JSX where you render `{children}` in the `shellComponent`.

Here is an example layout that includes a header:

```tsx
import { HeadContent, Scripts, createRootRoute } from '@tanstack/react-router'

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title: 'My App' },
    ],
  }),
  shellComponent: ({ children }) => (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        <header>
          <nav>
            <Link to="/">Home</Link>
            <Link to="/about">About</Link>
          </nav>
        </header>
        {children}
        <Scripts />
      </body>
    </html>
  ),
})
```

More information on layouts can be found in the [Layouts documentation](https://tanstack.com/router/latest/docs/framework/react/guide/routing-concepts#layouts).

## Server Functions

TanStack Start provides server functions that allow you to write server-side code that seamlessly integrates with your client components.

```tsx
import { createServerFn } from '@tanstack/react-start'

const getServerTime = createServerFn({
  method: 'GET',
}).handler(async () => {
  return new Date().toISOString()
})

// Use in a component
function MyComponent() {
  const [time, setTime] = useState('')
  
  useEffect(() => {
    getServerTime().then(setTime)
  }, [])
  
  return <div>Server time: {time}</div>
}
```

## API Routes

You can create API routes by using the `server` property in your route definitions:

```tsx
import { createFileRoute } from '@tanstack/react-router'
import { json } from '@tanstack/react-start'

export const Route = createFileRoute('/api/hello')({
  server: {
    handlers: {
      GET: () => json({ message: 'Hello, World!' }),
    },
  },
})
```

## Data Fetching

There are multiple ways to fetch data in your application. You can use TanStack Query to fetch data from a server. But you can also use the `loader` functionality built into TanStack Router to load the data for a route before it's rendered.

For example:

```tsx
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/people')({
  loader: async () => {
    const response = await fetch('https://swapi.dev/api/people')
    return response.json()
  },
  component: PeopleComponent,
})

function PeopleComponent() {
  const data = Route.useLoaderData()
  return (
    <ul>
      {data.results.map((person) => (
        <li key={person.name}>{person.name}</li>
      ))}
    </ul>
  )
}
```

Loaders simplify your data fetching logic dramatically. Check out more information in the [Loader documentation](https://tanstack.com/router/latest/docs/framework/react/guide/data-loading#loader-parameters).



# Learn More

You can learn more about all of the offerings from TanStack in the [TanStack documentation](https://tanstack.com).

For TanStack Start specific documentation, visit [TanStack Start](https://tanstack.com/start).
