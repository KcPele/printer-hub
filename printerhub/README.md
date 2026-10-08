# PrinterHub (the app)

The iOS and Android app. It finds printers and scanners on the local network, runs print and scan jobs against them directly, and tells the PrinterHub backend what happened.

```bash
make simulator   # a fake printer on 127.0.0.1:8631   (from the repo root)
make dev         # the backend on localhost:8000
make app-dev     # the app, development flavor, on a connected device or simulator
```

In the app, add the simulator as `127.0.0.1:8631`.

## Flavors

| Flavor | App ID | Backend | Launcher icon |
|---|---|---|---|
| development | `com.kcpele.printerhub.dev` | `localhost:8000` | Orange, DEV flag |
| staging | `com.kcpele.printerhub.stg` | Production API | Indigo, STG flag |
| production | `com.kcpele.printerhub` | Production API | Mint |

```bash
flutter run --flavor development --target lib/main_development.dart
```

On an Android emulator, `localhost` is the emulator itself. Point the app at the host with `--dart-define=API_BASE_URL=http://10.0.2.2:8000`.

## Layout

- `lib/<feature>/` holds a feature's screens (`view/`), state (`cubit/`), and widgets.
- `packages/` holds everything reusable, each tested on its own. `docs/mobile-app-implementation.md` in the repo root says what each is for.

## Checks

```bash
make app-check            # format, lints, and tests at 100% coverage, app and packages
make app-simulator-test   # printer protocols against the simulator
make app-smoke            # the API client against a local backend
make app-live-test        # adding the simulated printer through a real backend
```

## The mark, the icon, and the launch screen

The PrinterHub mark is described once, in `tool/brand/generate.py`. `make app-brand` writes every form of it: the SVGs the app uses, the iOS icon bundles, the Android launcher icons, and the launch images. Change the mark there, never in the generated files.

iOS keeps a copy of an app's launch screen. After changing it, delete the app and restart the simulator or phone to see the new one.
