# Publishing the Android app on Google Play

The app is `com.kcpele.printerhub` (the `production` flavor). Play keeps that
name for ever: it cannot be changed after the first upload.

## The upload key

Play signs the app people download with its own key. We sign what we upload
with an upload key, which only proves an upload came from us. It lives on
the owner's machine, never in this repository (`*.jks` and `key.properties`
are ignored by git).

Make it once:

```bash
keytool -genkey -v -keystore ~/printerhub-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then write `printerhub/android/key.properties`:

```properties
storePassword=<the password chosen>
keyPassword=<the password chosen>
keyAlias=upload
storeFile=/Users/<you>/printerhub-upload.jks
```

Keep the `.jks` file and its password somewhere safe besides this machine.
If the upload key is lost, Play support can reset it, but that takes days.

A build machine can give the same four values as `ANDROID_KEYSTORE_PATH`,
`ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`, and
`ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD` instead.

## Each release

1. Raise `version` in `printerhub/pubspec.yaml`. The part after `+` is the
   build number, which must go up with every upload: `1.0.0+1`, then
   `1.0.1+2`, and so on.
2. Push the backend first when the release relies on a backend change.
3. `make app-release`, then upload
   `printerhub/build/app/outputs/bundle/productionRelease/app-production-release.aab`.

## The first release

New personal developer accounts must run a closed test with at least 12
testers for 14 days before the app can go to production. Start with
internal testing (no review wait), then a closed test.

What Play Console asks for, and where it is:

| Asks for | Answer |
|---|---|
| Privacy policy | `https://printerhub.kcpele.com/privacy` |
| Account deletion link | `https://printerhub.kcpele.com/delete-account` |
| App access (reviewers sign in) | A test account made for reviewers, given in the console, never in this repository |
| Ads | No ads |
| Content rating | Utility / productivity, no user-generated content shown to strangers |
| Target audience | 18 and over (or 13 and over); not designed for children |
| Data safety | See below |

### Data safety

Collected, all **required for the app to work**, **encrypted in transit**,
**not shared with third parties** beyond the providers that run the
service, and **deletable on request**:

- **Personal info:** name, email address (account management).
- **Files and docs:** documents the person keeps in their account (app
  functionality).
- **App activity:** print, scan, and copy history (app functionality).
- **Device or other IDs:** a notification token per phone (app
  functionality).

Not collected: location (asked for only on Android 11 and older, where
Bluetooth scanning requires it; it is never recorded), photos (read only
when chosen, and kept only as part of a document the person saves),
contacts, payments, health, messages.

### Permissions to explain

| Permission | Why |
|---|---|
| Camera | Scanning pages and reading QR codes |
| Nearby devices, Bluetooth, NFC | Finding a printer |
| Location (Android 11 and older) | Required by Android for Bluetooth scanning there |
| Wi-Fi state, multicast | Finding printers on the local network |
| Notifications | Job finished or failed, invitations |

## Store listing

**App name:** PrinterHub

**Short description** (80 characters at most):

> Print, scan and copy from your phone. Plus PDF tools that work anywhere.

**Full description:**

> PrinterHub finds the printers around you, works out what each one can do,
> and picks a connection that works. Printing, scanning and copying take one
> tap, not a networking lesson.
>
> PRINT, SCAN AND COPY
> • Find printers on your Wi-Fi, by address, by QR code, by tapping with NFC,
>   or over Bluetooth
> • Print PDFs and photos with only the options your printer really has
> • Scan from the printer's glass or feeder, or with your phone's camera
> • Copy in one tap: scan and print together
> • See toner and paper levels, and every job's progress
>
> TOOLS THAT WORK WITH YOUR PHONE ALONE
> • Scan documents with the camera, straightened automatically
> • Crop, turn and highlight any picture
> • Sign or watermark any PDF, with a drawn signature or a photo of yours
> • PDF to pictures, pictures to PDF, merge files, keep only some pages
> • ID and passport photos at official sizes
> • Split a photo of an open book into its two pages
> • Make a PDF searchable, or lock it with a password
> • Print photos several to a page, QR code signs, notes, lined paper and
>   calendars
>
> YOUR DOCUMENTS, KEPT FOR YOU
> Everything you scan or make is saved without asking: on your phone at
> once, and in your account when you are online, so you find it again on any
> phone you sign in on. Nothing is shared with your workspace until you
> choose to.
>
> PRIVATE BY DESIGN
> Your pages go straight from your phone to the printer on your own network.
> Text is read on your phone, and your signature never leaves it.
>
> FOR TEAMS
> Share printers, presets and documents with a workspace, invite people, and
> see who printed what.

**Category:** Productivity

**Screenshots:** at least two phone screenshots, 1080 × 1920 or larger:
Home with a printer, the print screen, the Tools tab, a scan being saved,
the ID photo maker, Activity with recent documents.

**Feature graphic:** 1024 × 500, the same artwork as the website's share
image (`frontend/public/og-image.png`) at that size.
