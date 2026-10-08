# PrinterHub Mobile — Implementation Document

**Date:** 2026-10-07
**Status:** Milestone A0 is in progress. Done: the three themes, theme switching that survives a restart, the shared widgets, the gallery, and the themed illustration pipeline. The generated Dart API client, with session renewal and typed errors, is in `packages/api_client`. The welcome screens, the four-area shell, and Settings with the theme picker are built. A1 is built: register, sign in, password reset, email verification, workspaces, and sign-out, checked end to end against a local backend. A1 is complete: the phone registers itself with the account each time a session starts, and Settings has the profile, change password, devices and sessions, and delete account screens. A2 is partly built: adding a printer by address, the printer list, and printer detail with live status and supplies, checked on the iOS simulator against the printer simulator. Also built, ahead of A6: the ways to connect. Adding a printer opens on the printers found on the Wi-Fi network, then offers an address, a QR code, an NFC tap, Wi-Fi Direct, and Bluetooth, and a printer can be shared with a pairing code. Discovery was checked on the iOS simulator; NFC, Bluetooth, and the camera need a real phone. The protocol code was then hardened against what real printers do (`docs/printer-compatibility.md`): print formats other than PDF, printers that want a password, IPP 1.1, and scanner retries and quirks. A printer that asks for a user name and password can be added, and its password is saved with it. The catalogue is built: 27 printer families from the backend, searchable, each with what its models usually do and what to do on the printer first, and a printer's own page passes on its family's tips. Each of a printer's connections is tried when it is checked and its health recorded; a screen per printer shows them in order, and reorders, removes, adds, and re-keys them. A printer can be asked again what it can do. A2 is complete. A3 is partly built: a PDF or picture is chosen from the phone, shown with its first page, given the options the printer offers, and sent by the app itself; the job is recorded with the backend at each step, and kept on the phone while offline. A printer that reads neither PDF nor JPEG is sent drawn pages, and one that takes nothing the app can make is handed to the phone's own print dialog. Checked on the iOS simulator against the printer simulator and a local backend. Activity lists the workspace's jobs, newest first, with filters and a page per job: what was asked for, each step with its time, why it failed, and whether it moved to another connection. Opening Activity sends what the phone recorded while offline; a job still only on the phone is marked so. A failed job printed again the same way is recorded as another try of it. The choices for a print can be saved under a name, for the person or, by an admin, for the workspace; saved settings are offered above the choices, one can be marked as what every print on that printer starts from, and each can be renamed, replaced, and deleted. Still to build in A3: receiving a file shared from another app. A4 is partly built: a printer that scans has a Scan screen offering what its scanner can do (glass or feeder, colour, both sides, detail, paper size); pages are kept as they arrive, looked over, reordered, removed, and added to by scanning again; the result is saved as one PDF or as pictures and handed to the phone's share sheet; each run of the scanner is recorded as a job. Checked on the iOS simulator against the printer simulator. A finished scan can be kept in the workspace: its file goes straight from the phone to the workspace's storage over a signed link, and an upload that did not finish is sent again without making a second record. Documents, reached from Activity, lists what the workspace keeps, searches it by name, fetches a file back to open or share, and renames and deletes. Checked on the iOS simulator against a local backend and its storage. Still to build in A4: scan then print, ID card, camera capture, and text recognition. A5 is partly built: Home has a bell that counts what the account has not read, counted again as the app comes back to the front; the notifications screen lists what it was told, marks it read, and opens the job a notification is about, in the workspace it happened in. Still to build in A5: push, which waits on the Firebase project. The workspace is built: Settings opens its name and rules (the most copies in a job, whether documents may be kept in it), which an owner or admin changes; its people, with their roles, invitations waiting, and inviting someone by a code shown once; the invitations a person was sent, taken up there or by typing a code; and a log of what was done and by whom. Leaving or deleting a workspace moves on to the next, or to making one. What is switched on for a workspace is read as the app starts (`FeaturesCubit`); nothing is behind a switch yet. A phone in the devices list can be given a name of the person's own, which is kept when the phone registers again. A job the app was closed during is settled by asking the printer (`JobRecovery`). A finished scan and a kept document can be printed. A PDF or picture shared or opened from another app opens in PrinterHub, ready to print; that is checked on iOS, and built but not yet tried on Android. An ID card is scanned front and back onto one page. Section 16 lists what is left, in the order it will be built, and what each step needs from the owner. Section 14 records the owner's decisions and the questions still open.
**Requirements:** `PrinterHub_FRD_v2.0_Mobile_First.md` §7 (FR-MOB), §8 (FR-CON), §55.2 (mobile MVP), §60 (acceptance on the Xerox VersaLink C7130)
**Design references:** `design/`, on the owner's machine only. The folder is ignored by git.

## 1. What we are building

PrinterHub Mobile is the iOS and Android app. It is the product's main client and its local printer bridge: the phone talks to the printer over the local network, and tells the backend what happened.

The user's path is three steps: **find a printer, tap it, use it.** Everything in this document serves that.

Three properties shape the app:

1. **The phone does the work.** Printing, scanning, and status checks run on the device. The backend holds identity, printer profiles, job history, and notifications. A local job never needs its document to leave the phone.
2. **Only what the printer can do is shown.** Every option on screen comes from the capabilities the app probed from the device. A printer without a document feeder shows no feeder option.
3. **It keeps working offline.** A paired printer can print and scan with no internet. History syncs when the connection returns.

## 2. Decisions

| Decision | Choice | Reason |
|---|---|---|
| Framework | Flutter 3.47, Dart 3.13 | Owner's choice. This replaces the React Native recommendation in FRD §58. |
| Project template | Very Good CLI 1.5, `flutter_app` (Very Good Core 1.6), Android and iOS only | Flavors, strict lints, localization, and a tested CI setup from the first commit. Generated; lives in `printerhub/` |
| App ID | `com.kcpele.printerhub` | Matches the app already registered in Firebase |
| State management | `flutter_bloc` | The template's convention; one pattern across the app |
| Navigation | `go_router` | Declarative routes, deep links for pairing and notifications |
| API access | A Dart client generated from `backend/openapi.json` | One contract for every client. The TypeScript client in `packages/api-client` serves the later web app; Dart cannot use it |
| Printer protocols | IPP and eSCL written in Dart, in their own packages | Testable without a phone, against `backend/simulator` |
| Local data | SQLite through `drift`; secrets in the platform keystore | Offline profiles, the job queue, and FR-MOB-018 |
| Push | Firebase Cloud Messaging | The backend's only channel to clients |
| Themes | Three, switchable in Settings. One layout in three skins. Light only at first | Owner's decision. See §4 |
| Fonts | Lufga (Volt, licensed by the owner), Plus Jakarta Sans (Indigo), Manrope (Mint), bundled in the app | Works offline; no font is fetched at run time |
| Artwork | SVG illustrations, icons, and printer drawings made for the app | Owner's decision. See §4.1 |

## 3. Repository layout

The app is a Flutter project in the monorepo. Reusable parts are packages inside it, so each can be tested alone.

```
printerhub/                        # the Flutter app
├── lib/
│   ├── app/                       # root widget, router, theme wiring
│   ├── bootstrap.dart
│   ├── main_development.dart      # one entry point per flavor
│   ├── main_staging.dart
│   ├── main_production.dart
│   ├── l10n/                      # every user-facing string
│   └── <feature>/                 # view/, bloc/, widgets/
├── packages/
│   ├── app_ui/                    # design tokens, the three themes, shared widgets
│   ├── api_client/                # generated from backend/openapi.json
│   ├── printer_protocols/         # IPP codec and client, eSCL client. Pure Dart
│   ├── printer_discovery/         # Bonjour, QR and NFC payloads, Bluetooth proximity
│   ├── connection_engine/         # probing a device, certificate trust; the job runner later
│   ├── printers_repository/       # a workspace's printers, and what each device reports
│   ├── local_store/               # secrets in the platform keystore; the job queue later
│   ├── auth_repository/           # sign-in, the session, the signed-in user
│   ├── organizations_repository/  # workspaces
│   ├── jobs_repository/           # jobs recorded with the backend, an outbox for offline, saved presets
│   ├── documents_repository/      # documents kept in the workspace, and their files
│   ├── notifications_repository/  # what the account was told, and what of it was read
│   ├── preferences_repository/    # device preferences: the chosen theme
│   └── *_repository/              # auth, printers, jobs, documents, notifications
└── test/
```

Dependencies point one way:

```
feature (bloc + views)  →  repository  →  api_client · local_store · connection_engine
                                                              ↓
                                             printer_protocols · printer_discovery
```

A view never calls the API client or a protocol directly. A package never imports from `lib/`.

## 4. Themes

The app ships three themes. The user picks one in Settings, and the choice applies at once. Mint is the default.

A theme changes colour, type, shape, and elevation. It never changes layout, navigation, or wording. Every screen is built once and must look right in all three.

| | **Volt** | **Indigo** | **Mint** |
|---|---|---|---|
| Design reference | `app theme 1.webp`, `printer-connect-screen-design.webp` | `app theme 2.webp` | `app theme 3.webp` |
| Character | Bold, high contrast | Soft, friendly | Clean, technical |
| Primary | `#FFFF1E` | `#4856EB` | `#46D7B7` |
| Text on primary | `#212121` | `#FFFFFF` | `#0B3B32` |
| Brand colour as text (`emphasis`) | `#212121` | `#4856EB` | `#0A7461` |
| Background | `#EEEEEE` | `#EFF2FA` | `#FFFFFF` |
| Surface (cards) | `#FFFFFF` | `#FFFFFF` | `#F7F7F7` |
| Inverse surface | `#212121` | `#1C1E2B` | `#1A1A1A` |
| Text | `#212121` | `#1C1E2B` | `#1A1A1A` |
| Secondary accent | none | `#3AC67C` | `#FB7746` |
| Font | Lufga | Plus Jakarta Sans | Manrope |
| Corners | Full pills and circles | Large, 20 to 28 | Medium, 12 to 16 |
| Depth | Flat, light against dark blocks | Soft shadows | Flat, hairline borders |

Volt's values are stated in its design reference. Indigo's and Mint's primary and background colours were sampled from theirs; their text colours are our own choices, checked for contrast.

The design references show three different apps. We take each one's look (colour, type, shape, depth) and apply it to one set of screens. Their screen layouts are not copied.

Two values differ from what the references show, because the originals fail contrast. White text on Mint's primary is 1.8:1, so text on it is a deep teal. And a brand colour is not always readable as text on a light surface (Volt's yellow, Mint's mint), so each theme has an `emphasis` colour for brand-coloured text and icons. A test holds every text pair in every theme to WCAG AA.

Lufga is a commercial font, licensed by the owner. The repository is public, so its files are not committed: they go in `packages/app_ui/assets/fonts/lufga/`, which git ignores. The app bundles whatever is in that folder and registers it at start-up. Without the files, Volt uses the system font and everything still builds. **A release build must be made on a machine that has the files.**

**Rules:**

- A widget reads colour, text style, radius, and elevation from the theme. No hex value, font name, or radius number appears in a feature.
- Status colours (online, warning, error) and toner colours (cyan, magenta, yellow, black) are separate tokens. They mean the same thing in every theme and never take a theme's primary.
- Volt's primary is yellow. Yellow on white is unreadable, so in Volt the primary is a fill behind dark text, never a text or icon colour on a light surface.
- Each theme meets WCAG AA contrast for text (FRD §34).
- Every shared widget has a golden test in all three themes.

**Structure:** `app_ui` defines one `AppTheme` per theme, built from the same token set and exposed through Flutter's `ThemeExtension`. `ThemeCubit` holds the current choice and saves it on the device through `preferences_repository`; it is read before the first frame, so the app never opens in the wrong theme. From A1 the choice also syncs to the user's preferences on the backend, so it follows them to a new phone.

**Dark mode** is a second axis. A theme is a set of tokens per brightness, and a screen never asks which brightness it is in. The first release ships the light set of each theme. Adding dark means writing three more token sets and offering light, dark, and system in Settings (FRD §45); no screen changes.

### 4.1 Illustrations and artwork

The app's artwork is made for it: empty states, onboarding scenes, the printer drawings in the catalogue, and custom icons. Nothing is taken from the design references.

- **Format.** SVG, in `packages/app_ui/assets/`. A bitmap is used only for a real photograph.
- **One file, three themes.** An illustration is drawn in a small fixed palette of placeholder colours. `app_ui` maps each placeholder to a theme token when it renders, so the same file is yellow and charcoal in Volt, indigo in Indigo, and mint in Mint.
- **Printers as the hero.** Each catalogue family has a line drawing that shows its real shape: a floor-standing multifunction device looks different from a desktop inkjet. A generic drawing per category covers models without their own.
- **Meaning stays fixed.** Toner and status colours in a drawing are never remapped.
- **Motion** is added where it explains something (searching for printers, a job in progress), and respects the system's reduce-motion setting.

Artwork is added with the milestone whose screens need it, not in one batch.

## 5. Architecture inside a feature

Each feature folder holds its screens, its bloc or cubit, and widgets used only there.

- **View** renders state and sends events. No logic beyond layout.
- **Bloc** turns events into states by calling repositories. It holds no Flutter imports beyond `bloc`.
- **Repository** is the feature's source of truth. It decides between network and local data, and hides both.

Errors travel as typed failures. The API's `code` (for example `job.color_not_allowed`) maps to a localized message in one place, so the same backend error reads the same everywhere (FR-ERR-001).

## 6. Talking to the backend

`api_client` is generated from `backend/openapi.json`, the same file the TypeScript client is built from. `make openapi` regenerates all of them together, and CI fails when any is stale.

On top of the generated code, the package adds what every caller needs:

- **Token handling.** It sends the access token, refreshes an expired one, and repeats the request. Concurrent requests share one refresh, because the backend revokes a session whose refresh token is used twice.
- **Typed errors.** Every failure is a `Problem` with a stable `code`.
- **Idempotency keys.** Creating a job requires one. The key is saved with the job before the first attempt, so a retry after a crash reuses it.

The client is generated by `swagger_parser` (models and Retrofit interfaces) and `build_runner`, and checked in. Two things had to be right for the job types, a union of print, scan, and copy:

- The contract names each union (`JobRead`, `JobCreate`, `PresetRead`, `PresetCreate`). Written inline, the generator made a separate type for every endpoint.
- The generator leaves the JSON key names off a union's variants, so `build.yaml` tells `json_serializable` the API is snake_case. A test decodes every variant from a sample written from the contract.

Environments follow the template's flavors:

| Flavor | Backend | Printer |
|---|---|---|
| development | A backend on the developer's machine | `backend/simulator` |
| staging | Production API until a staging backend exists | Real hardware |
| production | `https://printerhub-backend.kcpele.com` | Real hardware |

## 7. Talking to the printer

This is the part no backend can do, and the core of the app.

### 7.1 Protocols

`printer_protocols` is pure Dart with no Flutter dependency, so it runs in plain unit tests against the simulator.

| Protocol | Used for | Operations |
|---|---|---|
| IPP / IPPS | Printing, status, supplies | Get-Printer-Attributes, Validate-Job, Print-Job, Get-Job-Attributes, Get-Jobs, Cancel-Job |
| eSCL (AirScan) | Scanning | ScannerCapabilities, ScannerStatus, ScanJobs, NextDocument |

Scan pages stream to a file as they arrive. A 50 MB scan must never sit in memory (FRD §48).

A document is sent in a form the printer takes, which is not always PDF: the app asks, then sends the file as it is, or draws its pages as PWG Raster or Apple Raster (`choosePrintFormat`, `RasterEncoder`). A printer that asks who is printing is signed in to with Digest or Basic. Scanners that answer "busy", misname their jobs, or need handling of their own are allowed for. `docs/printer-compatibility.md` records each of these, where it was learned, how it is tested, and what to run on the first real printer.

Printers present self-signed certificates on IPPS. The app trusts a printer's certificate on first use, remembers its fingerprint, and warns if it later changes. It never disables certificate checking globally.

### 7.2 Native paths

Where the operating system owns the flow, the app hands over a prepared document:

- **iOS:** the AirPrint sheet.
- **Android:** the system print framework and installed print services.

The app says plainly when it is using this path, because printer-specific options are then controlled by the system, not by PrinterHub (FR-PRN-028).

### 7.3 Probing

Adding a printer means asking it what it can do. The engine queries IPP attributes and eSCL capabilities, maps both into the backend's `PrinterCapabilities` shape, and stores one logical printer with every connection that worked.

The backend's capability registry tells the app what to expect from a model and which features are optional hardware. For the C7130 that means Wi-Fi, Wi-Fi Direct, and Bluetooth need the wireless kit, so the app checks for them and never assumes them.

### 7.4 Fallback without duplicates

Each printer has an ordered list of connections. The engine tries them in order (FR-MOB-022):

| | Print | Scan |
|---|---|---|
| 1 | Direct IPP / IPPS | Direct eSCL |
| 2 | Native print sheet | Phone camera capture |
| 3 | Wi-Fi Direct, then IPP | |
| 4 | Another saved printer, offered to the user | |

A fallback must never print twice. The rule:

- **The printer refused or was unreachable before accepting the document:** safe. Move to the next connection.
- **The connection dropped after the document was sent:** unknown. The engine asks the printer whether the job arrived. If it did, the engine follows that job. If the printer cannot be asked, the app stops and lets the user decide.

Every attempt is reported to the backend with the connection used, so the job record shows when a fallback happened.

### 7.5 Jobs and offline use

A job is created on the phone first, with its own ID and idempotency key, and saved locally. Then:

1. The app registers it with the backend, or queues that for later when offline.
2. The engine runs it against the printer.
3. Each state change is saved locally and reported.
4. When the connection returns, queued jobs and their history upload in one batch. Sending a batch twice changes nothing.

The app follows the backend's job states exactly: queued, processing, scanning, printing, then completed, failed, or cancelled.

## 8. Finding and adding a printer

This is the first thing a new user does, and the place the product is won or lost. It gets the most design attention.

**Add Printer** offers, in this order:

1. **Nearby printers.** Found automatically over the local network. One physical device appears once, even when it advertises several services.
2. **Browse supported printers.** A catalogue of popular models, by brand.
3. **Enter an address.** IP or hostname.
4. **Scan a code.** QR pairing from another member's phone.
5. **Tap the printer.** NFC, where the phone and printer support it.
6. **Wi-Fi Direct.** A guided flow.

### The printer catalogue

The catalogue lets someone see whether their printer works before they try, and what to expect from it.

- **Home:** featured models, then brands. The Xerox VersaLink C7130 is the featured reference device.
- **Model page:** a picture, what it can do (print, scan, copy, colour, two-sided, paper sizes), how it connects, and setup tips. For the C7130 that includes: "Wi-Fi needs the optional wireless kit. Without it, connect by network cable."
- **Add this printer:** starts discovery, looking for that model first.

The catalogue is the backend's capability registry, shown to people. It currently holds one family, the Xerox VersaLink C7100 series. Filling it is backend work listed in §12.

Models other than the C7130 have not been tested on hardware. Their pages say what the manufacturer documents, and the app still confirms everything by probing the actual device.

### After a printer is found

1. The app probes it and shows what it found in plain words: "Prints in colour, both sides. Scans from the glass and the feeder."
2. The user names it and may set a location.
3. A test page is offered.
4. The printer appears on Home.

## 9. Screens

Navigation is the same in every theme. Four areas sit in a bottom bar: Home, Printers, Activity, and Settings. Each keeps its own place, so returning to an area shows the screen that was left. Tapping the current area's tab goes back to its first screen.

A new install opens on the welcome screens: three introductions, then the theme choice. They are shown once per device.

| Area | Screens |
|---|---|
| Onboarding | Welcome (built), sign in, register, verify email, reset password |
| Home | Printers at a glance, recent activity, quick actions |
| Printers | List, detail (status, supplies, trays, connections), Add Printer, catalogue, diagnostics |
| Print | Choose file, preview, options, progress, result |
| Scan | Options, progress, page review and edit, save or share, ID card, camera capture |
| Activity | Job history with filters, job detail with attempts |
| Documents | Recent, search, detail |
| Notifications | List |
| Settings | **Theme** (built), profile, organization, members and invitations, devices and sessions, notification choices, delete account. A Developer section holds the design gallery until release |

Permissions are requested when a feature first needs them, with a sentence explaining why (FR-MOB-002). The app asks for nothing at first launch.

## 10. Platform setup

**iOS**

- Local network permission text, and the Bonjour service types the app browses: `_ipp._tcp`, `_ipps._tcp`, `_uscan._tcp`, `_uscans._tcp`.
- Local networking allowed in App Transport Security, so the app can reach printers over plain HTTP on the LAN.
- Camera, NFC, and Bluetooth usage texts, added with the milestone that needs each.
- A share extension, so other apps can send a document to PrinterHub.
- Push capability, and an APNs key uploaded to Firebase.

**Android**

- Network, nearby Wi-Fi devices, camera, NFC, and Bluetooth permissions, added with the milestone that needs each.
- Cleartext traffic allowed for local addresses only, through a network security configuration.
- An intent filter for shared PDFs and images.
- `google-services.json`. The file downloaded so far covers `com.kcpele.printerhub` only; see §14, open question 1.

## 11. Milestones

Each milestone ends with something a person can use and a test suite that passes. Numbers in the last column are the items of FRD §55.2.

| # | Milestone | Delivers | FRD §55.2 |
|---|---|---|---|
| **A0** | Foundation | Template, flavors, CI. `app_ui` with all three themes, a theme switcher, and a widget gallery. The generated API client with token handling. Error mapping, localization. | 1 |
| **A1** | Account | Register, sign in, verify email, reset password. Create or pick an organization. Device registration. Sessions. Delete account. Tokens in secure storage. | 1, 2 |
| **A2** | Printers | Add by address with probing. Automatic discovery. Printer list and detail. The catalogue. QR pairing. Tested end to end against the simulator. | 3, 4, 5, 6, 25, 26 |
| **A3** | Print | Pick or receive a file, preview, options from capabilities, direct IPP, native print sheet, job reporting, fallback, duplicate protection. | 9, 10, 11, 13, 14, 15, 24, 27 |
| **A4** | Scan | eSCL from glass and feeder, multi-page, review and edit, save and share, scan then print, ID card, camera capture, on-device OCR. | 16 to 23 |
| **A5** | Activity and sync | Job history, documents, notifications, push, offline queue and batch sync, status and supplies reporting. | 29, 30, 32 |
| **A6** | More ways to connect | Wi-Fi Direct, NFC, Bluetooth proximity, manual connection switching, diagnostics. | 7, 8, 12, 28, 31 |
| **A7** | Release | Accessibility pass, golden tests in three themes, store listings, and the FRD §60 acceptance run on a real C7130. | |

Where each stands (2026-10-08): A0, A1, and A2 are complete. A3 lacks only receiving a file from another app. A4 has scanning, review, saving, sharing, and keeping a scan in the workspace; scan then print, ID card, camera capture, and text recognition are left. A5 has history, documents, notifications, and offline sync; push is left. A6's ways to connect are built and wait on a real phone. A7 has not started. Section 16 turns what is left into steps.

**A0 is done when:** the app builds for iOS and Android in all three flavors; the theme can be switched and survives a restart; the gallery shows every shared widget in all three themes; the generated client signs in against a local backend; CI is green.

**A2 is done when:** a developer can start the simulator, add it by address, see its capabilities described correctly, and see the printer on another phone signed in to the same organization.

**A3 is done when:** a PDF prints to the simulator; switching the simulator offline mid-flow moves the job to the next connection; the job record shows the fallback; no test produces two jobs on the printer.

## 12. Backend work this needs

The backend is complete for the MVP as specified. The app adds four small requirements. All four are done.

| Change | Why |
|---|---|
| Add `app_theme` (`volt`, `indigo`, `mint`) to user preferences | The theme choice follows the user to a new device. Today the field only covers light and dark |
| Add catalogue fields to capability profiles: category, summary, popularity, setup tips | The catalogue needs more than capabilities to be worth browsing. Done; the app draws its own pictures, so there is no image field |
| Seed profiles for popular printer families | Done: 27 families |
| Generate the Dart client in `make openapi`, and check it in CI | Same guarantee the TypeScript client has |

Three more came out of building against it:

| Change | Why |
|---|---|
| The job-create contract says a client-made ID is a version 7 UUID | The history is listed by ID, newest first. The app made random IDs, and a job it created landed anywhere in the list. Found by the live test |
| Registering a device without a name keeps the name it has | The app registers the phone at every sign-in. A name its owner gave it in the app was being written over |
| The simulator's scanned page is a picture of a page | A one-pixel JPEG could not be put in a PDF or shown as a thumbnail |

### What the phone calls, and what it does not

Of the API's 88 operations the app calls 79. `make app-live-test` runs the repositories against a real backend, the printer simulator, and object storage; it is what found the three changes above.

| Not called | Why |
|---|---|
| The eight `admin` operations (capability profiles, feature flags) | For PrinterHub's own staff. They are left out of the Dart client on purpose |
| `get_connection` | A printer's record carries its connections, and the list of them is read when they are managed. Nothing needs one alone |

Push (`update_device` with a token, and the token on `register_device`) is wired in the repository and waits on the Firebase project: see section 14.

## 13. Testing

| Level | What | How |
|---|---|---|
| Unit | Blocs, repositories, protocol codecs, the fallback engine | `flutter test`, no device |
| Protocol | IPP and eSCL clients | Against `backend/simulator`, including its fault switches |
| Widget | Screens and shared widgets | Widget tests, plus golden files in three themes |
| End to end | Sign up, add the simulator, print, scan | `integration_test` on an emulator |
| Hardware | FRD §60 acceptance list | By hand on a real C7130, before release |

The template enforces 100% line coverage. Generated code is excluded.

The simulator's faults make failure paths testable without hardware: offline, paper jam, open door, empty feeder, low toner, and firmware without eSCL. It can also stand in for other printers: one that does not read PDF, one that wants a password, one that only speaks IPP 1.1, and a scanner that answers "busy" or misnames its jobs.

## 14. Decisions

**Decided by the owner (2026-10-07):**

| Question | Decision |
|---|---|
| One layout in three skins, or three layouts? | One layout, three skins |
| Dark variants for the first release? | Light only for all three, with the structure ready for dark |
| Fonts | Lufga for Volt (the owner holds a licence), Plus Jakarta Sans for Indigo, Manrope for Mint |
| Design references in the repository? | No. They stay on the owner's machine |
| Who makes the artwork? | It is drawn for the app as SVG (§4.1) |

**Still open.** Each has a default we build on until the owner says otherwise.

| # | Question | Blocks | Default |
|---|---|---|---|
| 1 | The three flavors use three app IDs (`.dev`, `.stg`, and none). Firebase knows only `com.kcpele.printerhub`. | A5 | Register the other two in the same Firebase project. It is free and takes minutes. |
| 2 | Which printer families go in the catalogue first? | A2 | The C7100 series plus about fifteen common office and home families from HP, Canon, Brother, Epson, and Xerox. |
| 3 | Bottom navigation: which four or five areas? | | Built with the default: Home, Printers, Activity, Settings. Print and Scan will be actions on Home and on each printer. |

## 15. Risks

| Risk | Effect | Response |
|---|---|---|
| The C7130's firmware may not expose eSCL | No direct scanning on the reference device | The app detects this and offers camera capture. Confirm on the real device early in A4, before building the scan editor around it |
| iOS suspends background apps | A long scan or print may be interrupted | Jobs are saved at every step and resume or report cleanly on return (FR-MOB-019) |
| Self-signed printer certificates | IPPS fails under default TLS rules | Trust on first use with a stored fingerprint (§7.1) |
| The Dart generator may handle the API's union types poorly | Hand-written models for jobs | Checked first, in A0 (§6) |
| Printers that accept only raster formats | A PDF cannot be sent directly | Answered: the app draws the pages and sends them as PWG Raster or Apple Raster (§7). The native print sheet is the last resort |
| Nothing has run on a real printer or on Android | A flow that passes against the simulator may fail on hardware | Steps 8 and 9 of section 16. The simulator stands in for the quirks that are documented; the first hardware session is for the ones that are not |

## 16. What is left, in order

Written 2026-10-08. Every step ends the way the milestones do: `make app-check` passes, and the step is tried on a device or simulator against the printer simulator and a local backend. A step that cannot be tried here says what it waits for.

Steps 1 to 4 are done. Steps 5 to 7 can be written and unit-tested here, but are only proved on a real phone. Steps 8 to 10 cannot start without the owner.

| # | Step | What it delivers | How it is built | Proved by | Waits on the owner for |
|---|---|---|---|---|---|
| 1 | **Finish a job the app was closed during.** Done 2026-10-08 | A print or scan that was running when the app closed is not left "Printing" for ever. On the next start the app asks the printer what became of it and records the answer; when the printer no longer knows, the job is marked as unknown, never as done | `JobsRepository` keeps the running job with the printer's own job number. `PrintersRepository` asks by that number (IPP Get-Job-Attributes), and by the job's name when the number was never learned. Runs at start and when Activity opens | Simulator: start a slow print, kill the app, reopen: the job ends as the printer says. Kill it before the printer has the job: it ends as failed, and nothing prints twice | Nothing |
| 2 | **Print what was scanned, and what is kept.** Done 2026-10-08 | "Print" beside "Share" on a finished scan, and on a document in Documents. Covers scan then print (FRD §55.2 item 20) | The print screen takes a document handed to it, as well as one picked. A kept document is fetched first | Simulator: scan, print the scan on the same printer; the printer simulator receives it once | Nothing |
| 3 | **Open a file from another app.** Done 2026-10-08 on iOS; the Android side builds and waits for a phone | PrinterHub appears when a PDF or picture is shared or opened from Files, Mail, or a browser. It opens on "which printer?", then the print screen. With no printer it opens Printers. A file that arrives before anyone is signed in waits until they are. Finishes A3 | iOS: the app declares the document types it opens (`Info.plist`), and `SceneDelegate.swift` passes each file on. Android: intent filters for sending and viewing PDF, JPEG, and PNG, and `MainActivity.kt` copies the file in and passes it on. Both speak over one channel, `printerhub/incoming_files`, behind `IncomingDocuments` in `lib/print/platform/`; no third-party plugin. `IncomingCubit` holds the document until the app can print it. Copies older than a day are cleared when the app starts | iOS simulator: a PDF shared from Files, with the app running and with it closed, opened "which printer?", then the print screen, and printed on the printer simulator. Android: `flutter build apk` passes; sharing a file is tried on the owner's phone in step 8 | Nothing |
| 4 | **ID card.** Done 2026-10-08 | Scan the front, turn the card over, scan the back: both come out on one page, at their true size. More cards can follow, a sheet each (FR-SCN-024) | An "ID card" switch in the scan options, shown when the scanner has a glass. It scans one corner of the glass, 92 mm by 60 mm, a side at a time, and `assembleScan` lays the sides two to a sheet of the paper chosen. The app tells the person when to turn the card over. The sides are placed, not straightened: a card laid crooked comes out crooked | Simulator: front, then back, saved as a one-page A4 PDF with the two pictures one above the other. True size waits for a real scanner (`docs/printer-compatibility.md`, checklist step 8) | Nothing |
| 5 | **Push on Android** | A finished or failed job, and an invitation, arrive as a notification. Tapping one opens what it is about. An open app refreshes instead | Firebase Messaging in the production flavor. The token goes to `registerDevice`, which already takes it; a refreshed token goes through `update_device`. Permission is asked for after the first job, not at first launch | An Android phone signed in: a job finishing elsewhere arrives. Until then: unit tests, and the key check already done against Firebase | The two FCM variables set in Dokploy. An Android phone. A decision on question 1 of section 14: register `.dev` and `.stg` in Firebase, or keep push in the production flavor only |
| 6 | **Scan with the camera** | "Use the camera" where a printer has no scanner, and as a choice everywhere else. Pages join the same review screen and are kept as `camera_scan`, never called a printer scan (FR-SCN-028) | The phone's own document scanner (VisionKit on iOS, ML Kit document scanner on Android), which finds the page's edges and straightens it, behind an interface in `lib/scan/platform/` | A real phone: the simulator has no camera. Here: the flow with a stand-in camera | A real phone |
| 7 | **Text in a scan** | The words in a scan are read on the phone. They are kept with a document that is kept in the workspace, so Documents finds it by what it says. Nothing is sent anywhere to be read | On-device recognition (Vision on iOS, ML Kit on Android) behind an interface. Switched on per workspace with the `scan.ocr` feature switch, the first use of `FeaturesCubit` | iOS simulator for iOS. A phone for Android | A real phone for Android |
| 8 | **Android** | The app builds and runs on Android in all three flavors, and every flow above works there | Fix what the first build shows: permissions (local network, NFC, Bluetooth, camera, notifications), the cleartext rule for printers, back-button behaviour, the launch screen | An emulator for everything but radios and camera; a phone for those | Install the Android command-line tools and accept the SDK licences (`flutter doctor` names both), and create an emulator or plug in a phone |
| 9 | **First session with a real printer** | The checklist in `docs/printer-compatibility.md`, run on the C7130 or any AirPrint or Mopria printer, with the model and firmware noted beside each result. What differs from the simulator becomes a fix, a test, and a knob in the simulator | A script that records what the printer says about itself, then the eleven steps | The printer itself | A printer on the same network as the phone, and an hour with it |
| 10 | **Release (A7)** | Accessibility pass, golden tests for the new screens in all three themes, store listings, and the FRD §60 acceptance run | As §11 | The acceptance run | Store accounts, and step 9 done |

Not in this list, by the owner's decision:

- **Push on iOS.** Later. It needs an APNs key uploaded to Firebase and the Push Notifications capability.
- **Admin screens** for the catalogue and the feature switches. With the web app and landing page, not in the phone. See "The admin dashboard" below.

### The admin dashboard: do not forget it

The backend has eight operations that only a super-user may call, and nothing calls them yet. They are for PrinterHub's own staff. When the landing page and web app come into this repository, an admin dashboard is built there, with `@printerhub/api-client`, which has these operations (the Dart client leaves them out on purpose).

| What the dashboard does | Operations |
|---|---|
| Add, replace, and delete a printer family in the catalogue the app shows | `create_profile`, `replace_profile`, `delete_profile` under `/api/v1/admin/capability-profiles` |
| List, create or change, and delete a feature switch | `list_feature_flags`, `put_feature_flag`, `delete_feature_flag` under `/api/v1/admin/feature-flags` |
| Switch a feature on or off for one workspace, or go back to the default | `put_feature_flag_override`, `delete_feature_flag_override` |

An account becomes a super-user with `python -m scripts.promote_superuser you@example.com` (`docs/deployment.md`). Until the dashboard exists, the same operations can be used from `/api/docs`.

### What the owner still holds

| Item | Needed for |
|---|---|
| `PRINTERHUB_PUSH_BACKEND=fcm` and `PRINTERHUB_FCM_SERVICE_ACCOUNT_JSON` in Dokploy | Step 5. The key itself was checked against Firebase and works |
| Question 1 of section 14: the `.dev` and `.stg` app IDs in Firebase | Step 5 in the development build |
| An Android phone or emulator. A debug build of the development flavor now succeeds on this machine (2026-10-08); the command-line tools are still missing, which only matters for creating an emulator | Steps 5 to 8 |
| A real phone. The owner has an Android phone to connect once steps 1 to 4 are done | Camera, NFC, Bluetooth, push |
| A printer | Step 9 |
| From earlier: the Resend sender domain, `PRINTERHUB_CORS_ORIGINS`, rotating the database and Redis passwords that were exposed, Dokploy watch paths, the Lufga font files, Apple's NFC Tag Reading capability | Release |

