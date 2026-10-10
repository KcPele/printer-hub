# PrinterHub

# dont ever say in your commit message, co-authored by claude

Backend-first, mobile-first printer and scanner platform. This repo is a monorepo: `backend/` (FastAPI), `printerhub/` (the Flutter app), `frontend/` (the landing page and the admin console), and `packages/api-client/` (the TypeScript client the web app uses).

**The backend never talks to a printer.** Clients run print and scan jobs on the local network and report state. Anything that needs to reach a printer belongs in a client or in `backend/simulator/`.

## Where things are

| Need | Read |
|---|---|
| Product requirements, FR-* IDs | `PrinterHub_FRD_v2.0_Mobile_First.md` (3,000 lines: grep for the FR ID or section) |
| Backend architecture and the reasons behind it | `docs/superpowers/specs/2026-10-07-backend-mvp-design.md` |
| Milestones and fixed interface names | `docs/superpowers/plans/2026-10-07-backend-mvp.md` |
| Commands | `make help` |
| Hosting, environment variables, push setup | `docs/deployment.md` |
| Printer simulator endpoints and faults | `backend/simulator/README.md` |
| What real printers and scanners do differently, and how the app copes | `docs/printer-compatibility.md` |
| API contract | `backend/openapi.json`, or `/api/docs` on a running server |
| Calling the API from the web app | `packages/api-client/README.md` |
| The web app: landing page and admin console | `frontend/README.md` |
| Calling the API from the Flutter app | `printerhub/packages/api_client/README.md` |
| Mobile app architecture, milestones, open decisions | `docs/mobile-app-implementation.md` |
| Features that could be added, and which cannot | `docs/feature-candidates.md` |
| Visual references for the three themes | `design/` (on the owner's machine only; ignored by git) |

## The mobile app has three themes

The user picks a theme in Settings and it applies at once. **Mint is the default.** **One layout, three skins:** every screen is built once and must look right in all three. A theme changes colour, type, shape, and elevation; layout, navigation, and wording stay the same. The files in `design/` are references for each skin's look, not screens to copy.

All three ship light only. Each theme is a set of tokens per brightness, so a dark variant is added in `app_ui` without touching a screen.

| | Volt | Indigo | Mint |
|---|---|---|---|
| Design file | `app theme 1.webp`, `printer-connect-screen-design.webp` | `app theme 2.webp` | `app theme 3.webp` |
| Primary | `#FFFF1E` | `#4856EB` | `#46D7B7` |
| Background | `#EEEEEE` | `#EFF2FA` | `#FFFFFF` |
| Dark surface and text | `#212121` | `#1C1E2B` | `#1A1A1A` |
| Font | Lufga | Plus Jakarta Sans | Manrope |
| Corners | Pills and circles | Large (20 to 28) | Medium (12 to 16) |
| Depth | Flat | Soft shadows | Hairline borders |

When building or changing any app UI:

- Take colour, text style, radius, and elevation from the theme tokens in `printerhub/packages/app_ui`. A feature contains no hex value, font name, or radius number.
- Check the result in all three themes (the gallery screen shows every shared widget), and add a shared widget to the golden test in `packages/app_ui`. After an intended visual change, run `make app-goldens`.
- `context.colors.primary` is a fill. For brand-coloured text or an icon on a light surface use `context.colors.emphasis`: Volt's primary is yellow and Mint's is a light mint, and neither can be read as text.
- A new colour pair that carries text is added to `packages/app_ui/test/src/theme/contrast_test.dart`, which holds every theme to WCAG AA.
- Status colours (online, warning, error) and toner colours keep their meaning in every theme; they are separate tokens from the primary.
- Illustrations, icons, and printer artwork are SVGs we draw ourselves, kept in `printerhub/packages/app_ui/assets/`. They are drawn in a fixed set of placeholder colours that map to theme tokens, so one file serves all three themes. No third-party artwork, and no bitmap where a vector will do.
- The look to aim for: clean, professional, and inviting, with the printer as the hero of the screen. Function comes first: a screen that looks good and cannot reach the printer is not done.

The full token table, and which values are still proposals, are in `docs/mobile-app-implementation.md` §4.

## Working in `printerhub/` (the Flutter app)

Generated with Very Good CLI (`very_good create flutter_app`). Flutter 3.47, Dart 3.13, iOS and Android only.

A change is done when `make app-check` passes: formatting, `very_good_analysis` lints, and tests with 100% line coverage, for the app and for each package under `printerhub/packages/`.

- **Three flavors**, each with its own entry point and app ID: `development` (`.dev`), `staging` (`.stg`), `production` (`com.kcpele.printerhub`). Run one with `make app-dev`, or `flutter run --flavor <name> --target lib/main_<name>.dart`.
- **A feature is a folder** under `lib/` with `view/`, `cubit/` or `bloc/`, and a barrel file. Tests mirror the path under `test/`.
- **State lives in blocs and cubits.** A view renders state and sends events; it holds no logic and calls no repository.
- **Tests run on a pretend API, not mocks of repositories.** `TestBackend` in `test/helpers/` puts the real client and repositories on a fake network. Inside `testWidgets`, a repository call awaited directly must go through `tester.runAsync`; under the fake clock it never completes.
- **Where someone belongs is decided in one function**, `redirectFor` in `app_router.dart`, from the session's stage. A screen never checks whether the user is signed in.
- **A form is a `SubmitCubit` subclass** with one `submit` method, and its screen ends with `SubmitSection`. API failures become words in `lib/errors/error_messages.dart` and nowhere else.
- **Routes** are named in `AppRoutes` and built in `lib/app/router/app_router.dart`. The four areas (Home, Printers, Activity, Settings) are branches of one shell; a screen inside an area is a child route of that branch.
- **Home offers only what works right now.** Its tiles are decided in `_Actions`: printing where a printer prints, the camera where the phone has one and the workspace has `camera_scan` on. A new tool gets a tile when it works, not before.
- **An empty list is a designed screen.** Use `EmptyState` from `app_ui` with an illustration and one sentence. A button is added only when the thing it starts exists.
- **Every user-facing string** goes in `lib/l10n/arb/app_en.arb` and is read through `context.l10n`.
- **Lufga, Volt's font, is commercial and this repository is public.** Its files live in `printerhub/packages/app_ui/assets/fonts/lufga/`, which git ignores. Never commit them, and never register a real font under the name `Lufga` in a test: fonts are global to a test run and it changes the Volt golden.
- **Reusable code becomes a package** under `printerhub/packages/`, tested on its own. A new package is added to the matrix in `.github/workflows/mobile-ci.yml`. `docs/mobile-app-implementation.md` §3 names them and the direction dependencies may point.
- **The app runs print and scan jobs itself**, against the printer on the local network. Develop against `backend/simulator` (`make simulator`). In the app, add it as `127.0.0.1:8631`: `localhost` can resolve to IPv6, which the simulator does not listen on.
- **Every way of finding a printer ends in the same place.** Nearby, address, QR, NFC, Wi-Fi Direct, and Bluetooth all lead to `AddPrinterCubit` asking the device what it is. Bluetooth and NFC only find a printer; the document always travels over the network. A new way is a new input to that cubit, not a new flow.
- **Code that talks to a phone's radio through a plugin** lives in `printer_discovery/lib/src/platform/` behind an interface, is excluded from coverage with a comment saying why, and has a stand-in in that package's `testing.dart`. Decisions never go in those files.
- **What a printer reports is worded in one place**, `lib/printers/printer_words.dart`: its standing, its alerts, what it can do. A screen never turns a status code into a sentence itself.
- **Never assume what a printer takes or how it behaves.** A document's format comes from `choosePrintFormat`, never a hard-coded `application/pdf`. A new quirk of a real device goes into `printer_protocols` with a test, a matching knob in `backend/simulator` when it can be simulated, and a line in `docs/printer-compatibility.md` saying where it was learned.
- **A print is one call**, `PrintersRepository.print`, started by `PrintCubit`. The cubit records the job with `JobsRepository` before the first byte is sent and reports each step after; a report never holds the screen back and never fails a print. What a print stage or failure code says to a person is in `lib/print/print_words.dart`.
- **A job the app was closed during is settled by `JobRecovery`**, at start, on coming back to the app, and when Activity opens. It asks the printer (`PrintersRepository.fate`) and only ever marks a job done when the printer says so; a job the printer no longer knows is recorded as unknown. A new kind of job has to say here what an interrupted one becomes.
- **The job history refreshes itself.** `JobsRepository.changes` fires when a job begins or ends, and `ActivityCubit` reads again. What a job's status, kind, and failure say is in `lib/activity/job_words.dart`.
- **Anything the app creates before the API hears of it gets its id from `newRecordId`**, never a random one: the API lists records by id, newest first.
- **Settings from anywhere but the options on screen are fitted to the printer first**, with `PrintCubit.fitted`: a saved preset or an old job may ask for a tray this printer does not have.
- **A scan is one call**, `PrintersRepository.scan`, started by `ScanCubit`, which records each run of the scanner as a job. Pages are files from the moment they arrive; `assembleScan` makes the PDF. What a scan stage or failure code says is in `lib/scan/scan_words.dart`, and the share sheet is a plugin behind `ScanSharer` in `lib/scan/platform/`. The words in a scan are read on the phone, by `ScanTextReader`, when it is kept in a workspace with `local_ocr` on; a scan is kept whether or not they can be read. The phone's camera is another source of pages for the same screen (`PageCamera`, `ScanCubit.useCamera`), offered where the workspace has `camera_scan` on; a scan with a camera page is kept as `camera_scan`, never as the printer's. `ScanPage` with no printer is the phone alone (`AppRoutes.scan`, opened from Home): only the camera adds pages, and the result prints on any printer the workspace has. An ID card is a mode of the same screen (`ScanState.card`), not a second flow: it changes the area asked for and how `assembleScan` lays the pages out.
- **Every tool is listed in one place**, `toolTiles` in `lib/tools/tool_list.dart`. Home shows the first few and "See all" opens `ToolsPage` with the rest. A tool that works on a file is a cubit with `ToolState` and a screen built on `ToolScaffold`; what it makes comes from a plain function in `tools_output.dart` or `photo_sheet.dart`.
- **A tool that makes a document from what is typed or chosen is a `MakeCubit`** with its choices, shown with `MakeScaffold`: a sign with a QR code, a note, a ruled page, pages several to a sheet. The PDF comes from a plain function in `made_pages.dart`, which takes its words and font as arguments and knows nothing of the app's language.
- **Files from the phone join a scan as pages**, through `ScanCubit.addFiles`: a picture as it is, a PDF drawn a page at a time. Merging files and keeping some pages of a PDF are the scan screen begun that way, not screens of their own. A page drawn from a PDF is a picture, and the screen says so.
- **A link is opened through `LinkOpener`**, a plugin behind an interface in `lib/tools/platform/`. What a code read by the camera holds is decided by `ReadCode`.
- **What is added to a scan when it is saved is a `ScanFinish`**: a look, a date stamp, a watermark, a signature. `assembleScan` draws them; the pages themselves are never changed, so going back undoes any of it. A new finishing touch is a field there, not a new step.
- **A signature stays on the phone.** `SignatureStore` keeps it in secure storage and nothing sends it to the API; it leaves only as part of a document the person saves. `SignCubit` decides where it sits, in parts of the sheet.
- **A copy is a scan and then a print**, run by `CopyCubit` over `ScanCubit` and `PrintCubit`, and recorded as those two jobs. It never prints pages from a scan that was stopped.
- **Whatever the app makes is kept without being asked**, by `Library` in `lib/library/`: a scan when it is saved, a tool's result when it is made. The file is copied into the app's own folder at once, then sent to the person's account, at once when the API can be reached and at the next sync when it cannot. A cubit that makes a file takes a `KeepFile` (`Library.keeper`) and calls it; it never uploads anything itself.
- **A document is its owner's alone until they share it.** `shared` on a document is what lets the workspace's other members see it; nothing sets it but the person choosing "Share with your workspace". The phone and the account know a document by the same id, from `newRecordId`.
- **`SyncCubit` sends what waits on the phone**: when a workspace is opened, when the app comes back to the front, every few minutes, and from "Sync now" in Settings. Only what the account does not have is sent.
- **A list of documents is read through `DocumentsCubit`**, which puts what waits on the phone ahead of what the account has, and shows the phone's own when the API cannot be reached. `RecentDocuments` is that list's first few, for any screen: the scan screen and Activity have it.
- **A document's file never passes through the API.** `DocumentsRepository` asks the API for a signed link and `FileTransfer` moves the file to or from the storage with nothing of the account attached. A record whose file did not arrive is finished with `finish`, never made again.
- **A change to which workspaces someone has ends with `SessionCubit.loadWorkspaces()`**: renaming, leaving, deleting, joining. The session picks the next workspace, or asks for one, and the router follows. Invitations by address need a verified email; a code does not.
- **Something behind a switch asks `FeaturesCubit.enabled('name')`**, which follows the workspace. Unknown is off. The names are the keys the backend seeds (`local_ocr`, `camera_scan`, `cloud_documents`, ...), not ones made up in the app.
- **Notifications belong to the account, not a workspace.** `UnreadCubit` holds the badge's count for the whole app and counts again when someone signs in, when something is read, and when the app returns to the front. Opening a notification moves to the workspace it happened in first.
- **A file another app hands over arrives through `IncomingDocuments`**, a channel to `SceneDelegate.swift` and `MainActivity.kt` with no plugin between. `IncomingCubit` keeps it until someone is signed in and the printers are known; `App` then asks which printer and opens the print screen. A new kind of file is added in three places: `PickedDocument.mimeType`, `Info.plist`, and the intent filters in `AndroidManifest.xml`.
- **The file picker and the page renderer are plugins**, kept in `lib/print/platform/` behind `DocumentPicker` and `PageRenderer`, excluded from coverage, with stand-ins in `test/helpers/fake_documents.dart`.
- **Three kinds of test reach further than unit tests**, and skip themselves when what they need is not running: `make app-simulator-test` (protocols and probe against the simulator), `make app-smoke` (the API client against a local backend), `make app-live-test` (adding the simulated printer, recording jobs, saving presets, and keeping a document through a real backend and its storage). Run it after changing a repository: it is what catches an app and a backend that disagree. The live tests make accounts on the backend they find, so they run only when asked for this way, never as part of `make app-check`.

## Working in `frontend/` (the web app)

TanStack Start, React 19, Tailwind 4, Biome. Installed and run with npm from `frontend/`; it is not part of the pnpm workspace. A change is done when `npm run check` and `npm run typecheck` pass.

- **Colour, shape, and type come from the theme tokens in `src/styles.css`** (`--p`, `--em`, `--sf`, `--rc`, ...), the same three themes as the phone. No hex value for anything a theme decides.
- **The admin console is everything under `/admin`.** `src/routes/admin.tsx` switches off server rendering for it, because its sign-in lives in the browser's session storage. `AdminShell` lets in only a signed-in super-user.
- **It reaches the API only through `@printerhub/api-client`**, by the path in `tsconfig.json`: the source in `packages/api-client`, not a copy. That is why the Docker image is built from the repository root.
- **A page is laid out for a phone first.** Check it at 375 pixels wide: nothing scrolls sideways, and a row that does not fit wraps.

## Working in `backend/`

Run everything through `make` from the repo root, or `uv run <cmd>` from `backend/`. Python is 3.14, managed by uv.

A change is done when `make check` passes (ruff, mypy strict, pytest). Tests need `make infra` running.

### Module shape

Each domain lives in `backend/app/modules/<name>/` with four files:

- `models.py` — SQLAlchemy tables.
- `schemas.py` — Pydantic request and response models, subclassing `ApiModel` from `app/core/schemas.py`.
- `service.py` — business rules, queries, audit writes, event emission. Plain async functions taking `session` first. No FastAPI imports.
- `router.py` — HTTP mapping only: parse input, call the service, return a schema.

A module reaches another module through its `service`, never its `models` queries or `router`.

Adding a module: create the four files, import the models in `app/models.py`, mount the router in `app/api.py`, run `make migration m="..."`, review the generated file.

### Rules that hold everywhere

- **Tenancy.** Every organization-owned route takes `ctx: Annotated[OrgContext, Depends(require(Permission.X))]` from `app/modules/organizations/deps.py`. Every query in its service filters by `ctx.organization.id`. A resource in another organization is a 404, the same as a missing one.
- **Unit of work.** The session dependency commits. Services call `await session.flush()` to get IDs and surface constraint errors; they leave `commit()` to the dependency.
- **Side effects after commit.** Background tasks go through `tasks.enqueue(session, ...)`, which waits for the commit, so a failed request sends nothing. Use `db.after_commit` for any new kind of side effect.
- **One process.** The arq worker runs inside the API process (`embedded_worker`), so the deployment is a single container. A task function lives in `app/worker.py`, opens its own `session_scope`, and takes string arguments.
- **An email is written once, in its module's `emails.py`, and goes out as text and as HTML.** The HTML comes from `app/core/email_layout.py`, the one look every email shares: no pictures, nothing fetched, everything given to it escaped. The text is never dropped; the inbox preview never holds a code.
- **FCM is the only channel to clients.** A user-facing notification is an in-app row plus an FCM push whose data payload carries the event type and IDs, so an open app can refresh from it. There is no WebSocket server; shared state such as printer status is refetched by clients.
- **Routers return schemas.** Build the response with `Schema.model_validate(obj)` inside the endpoint. Relationships are loaded explicitly in the service; nothing lazy-loads.
- **A failure that must leave a mark.** Raising rolls the request back. When a rejected request still has to change something (a wrong code counts as an attempt, a replayed refresh token revokes the session), call `await session.commit()` just before raising, with a comment saying why. These are the only places a service commits.
- **Errors.** Raise an `AppError` subclass from `app/core/errors.py` with a dotted `code` such as `job.invalid_transition`. Codes are API contract: add new ones, keep existing ones stable.
- **Audit.** A service that changes membership, permissions, printers, connections, or credentials calls `audit.record(...)` in the same transaction.
- **Enums.** Declare a `StrEnum` and map it with `db.str_enum(...)`. It stores a VARCHAR, so a new member needs no migration.
- **IDs and time.** IDs come from `ids.new_id()` (UUIDv7, sortable by creation). Datetimes are timezone-aware UTC.
- **Secrets.** Connection credentials go through `crypto.encrypt_json` and stay out of every response schema. Log with structlog key-value pairs; the redaction processor keys off names like `password` and `token`, so name sensitive fields accordingly.
- **Pagination.** List endpoints take `PageParams` and return `Page[Schema]` via `pagination.paginate`.
- **Idempotency.** A `POST` that creates a job or document reads the `Idempotency-Key` header through `app/core/idempotency.py`.

### Migrations

`make migration m="..."` autogenerates from the models. Read the result before committing: check index and constraint names, and add data backfills by hand. One migration per change, never edit a migration that has been merged.

### Tests

- Tests exercise behavior through the HTTP API with the `client` fixture. Reach for a direct service or unit test when the logic is pure (state machines, codecs, permission maps).
- Each test runs in a rolled-back transaction on one connection, so requests inside a test are sequential.
- Arrange data with `tests/factories.py`. After an API call changes a row you hold, `await session.refresh(obj)`.
- Object storage, push, email, and the task queue use in-memory fakes, exposed as the `storage`, `push`, `mailbox`, and `task_queue` fixtures. A request that should notify someone is asserted on `task_queue`; delivery is asserted by calling the worker function and reading `push`. Tests marked `integration` hit MinIO.
- Use `@example.com` addresses; the email validator rejects reserved TLDs such as `.test`.

### Adapters

`app/adapters/push`, `app/adapters/email`, and `app/adapters/storage` each define a protocol in `base.py`, real implementations, and an in-memory fake. Services depend on the protocol. A new provider is a new file plus one branch in the factory function.

## Conventions

- Conventional Commits (`feat(jobs): ...`, `fix(auth): ...`). One logical change per commit.
- Run `make openapi` whenever a route or schema changes. It rewrites `backend/openapi.json`, the TypeScript types in `packages/api-client/src/schema.d.ts`, and the Dart client in `printerhub/packages/api_client/lib/src/generated/`; commit all three. CI fails when any is stale.
- An endpoint function's name is its operation ID and becomes the client method (`list_jobs` is `api.jobs.listJobs`), so it is unique across the API. A union of models is declared with `type Name = Annotated[A | B, Field(discriminator=...)]` so the contract names it.
- The contract is the source of the apps' types. When a generated type is looser than the API's behavior, fix the backend schema or `_polish_contract` in `app/main.py`, never the generated file.
- Apps reach the API only through a client generated from `backend/openapi.json`: the Dart client for the Flutter app, `@printerhub/api-client` for the web app.
- Local infrastructure uses offset host ports (Postgres 5433, Redis 6380) so it coexists with locally installed services.
- `main` deploys to production on push. The container runs `scripts/start.sh`: migrations, seed, then the API. A migration on `main` runs against the live database on the next deploy.
- `backend/simulator/` shares no code with `backend/app/`. Keep it that way: it stands in for hardware.
- Settings are `PRINTERHUB_*` environment variables defined in `backend/app/core/config.py`. Add new ones there and to `backend/.env.example`.
