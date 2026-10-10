# Features we can add

Written 2026-10-10. The starting point was the tools page of a scanner app (Scan, Import, Convert, Edit). This goes through every tool on it, says whether PrinterHub can have it, how it would be built here, and how big the work is. A few that suit a printer app better than a scanner app are added at the end.

Two rules decide most answers:

- **A document is worked on where it is: on the phone.** The backend never opens a file; it keeps one in storage when asked. So a feature either runs on the phone or it needs something this product does not have (a document-processing service).
- **A feature is listed as buildable only if it would really work**, not as a button that leads nowhere.

Sizes are estimates: **S** is a day or two, **M** is several days, **L** is a week or more. "Proved on" says where it can be checked before a release.

## What is already in the app

| Tool | Where it is |
|---|---|
| ID card, front and back on one page | Scan screen of a printer with a glass: the "ID card" switch |
| Extract text | The words of a scan are read on the phone when it is kept in the workspace, and Documents finds it by them |
| Import files | "Print a file" picks a PDF, JPEG, or PNG. A file shared or opened from another app opens in PrinterHub |
| Scan with the phone's camera | Scan screen, and now Home, with no printer needed. Written and unit-tested; not yet run on a phone |
| Print what was scanned | "Print it" on a finished scan |
| Keep, find, rename, delete documents | Documents, under Activity and on Home |

## Kept without being asked

Added 2026-10-10, after the first run on an Android phone: a scan came out clean, and then could not be found again.

- **Everything made is kept.** A scan when it is saved, and what a tool makes when it is made, is copied into the app's own folder and sent to the person's account. Nobody presses anything.
- **Online, it goes to the account at once. Offline, it stays on the phone** and is sent at the next sync: when the app is opened or comes back to the front, every few minutes, or from "Sync now" in Settings, which says how many are waiting.
- **It is the person's alone** until they choose "Share with your workspace", on the saved scan or from a document's menu. This needed a backend change: a `shared` flag on documents. Before it, an administrator could read every member's documents; now nobody sees a document that is not shared.
- **Where to find it again:** under the buttons on the scan screen, at the top of Activity, and in Documents. Each one can be opened, printed, renamed, shared, or deleted where it is listed, and opens with no network when this phone made it.
- **Home shows two printers**, with "See all" for the rest.

What it does not do: a document belongs to the workspace it was made in, so it is found again in that workspace on another phone, not in every workspace the person is in. Extracted text is shown and shared but not kept as a document. A copy (scan then print) keeps what it scanned, named "Copy" and the day.

Found while testing offline on the simulator, and fixed: Activity hid the phone's documents when the job history could not be read; kept files were written down by their full path, which changes when the app is updated; and scanning with the phone vanished from Home because the workspace's switches could not be asked for. With no network the app does not yet show the workspace's printers on Home after a restart: the list of printers is not kept on the phone.

## Built: the tools

All eleven were built on 2026-10-10. Each passes `make app-check` (unit and screen tests, full coverage). **None has been run on a phone yet**, and the ones that print were not run against the printer simulator after being written: that is the next thing to do.

Home shows the first four tools and a "See all" link to the Tools screen, which lists every one. The list is made in one place, `toolTiles` in `printerhub/lib/tools/tool_list.dart`.

| # | Feature | Where it is in the app | How it was built | Still to prove |
|---|---|---|---|---|
| 1 | **Extract text** | Tools: pick a picture or a PDF, see its words, copy them or share a text file | `ScanTextReader` reads pictures; a PDF's pages are drawn first with `PageRenderer` (`ExtractTextCubit`) | Reading on an Android phone |
| 2 | **Pictures to PDF** | Tools: pick several pictures; they open as pages in the scan's review screen | `ScanCubit.addPictures`, then `assembleScan` | A phone's photo picker |
| 3 | **PDF to pictures** | Tools: a PDF's pages as JPEGs, to the share sheet | `pagesAsPictures` in `tools_output.dart` | A large PDF on a phone |
| 4 | **PDF to one long picture** | Tools: every page stacked into one image. At most 20 pages | `pagesAsLongPicture` | The same |
| 5 | **ID card with the camera** | The "ID card" switch now works with the phone's camera, with or without a printer | The camera's two pictures are laid two to a sheet, each fitted to the standard card size | A phone: no camera runs on a simulator |
| 6 | **Timestamp** | "Finishing touches" on a scan's review screen: "Date and time" | Drawn on each sheet when the PDF is made (`ScanFinish.stamp`). PDF only | How it reads on paper |
| 7 | **Watermark** | The same card: a word across every sheet | `ScanFinish.watermark`, pale and at an angle | How it reads on paper |
| 8 | **Sign** | The same card: "Add your signature". Draw it once, drag it into place, choose its size and its sheet | `SignCubit` and `SignPage`. The signature is a PNG in the phone's secure storage (`SignatureStore`) and is never sent to the API. Set on the sheet by `assembleScan`. Not offered for an ID card | Drawing with a finger on a phone |
| 9 | **Page clean-up** | The same card: "Look", with Document, Whiteboard, and Black and white. "As scanned" is always there | `pictureWithLook`, applied when the scan is saved; the pages themselves are not changed | Real whiteboard photos |
| 10 | **Copy** | A Copy button on a printer that scans and prints, and a tile on Home | `CopyCubit` runs a scan and then a print. It is recorded as two jobs, a scan and a print, not as one copy job | The printer simulator, then a real device |
| 11 | **Print photos** | Tools: pick photos, a paper, and one, two, four, or passport-size to a sheet | `photoSheet` lays them out at the paper's true size, then the normal print | True size on paper |

### Eight more, added the same day

Built after a second look at the scanner app's tools page. The same holds: all pass `make app-check`, and none has run on a phone.

| # | Feature | Where it is in the app | How it was built | Still to prove |
|---|---|---|---|---|
| 12 | **Scan a code** | Tools: point the camera at a QR code or barcode. A link opens in the browser; a Wi-Fi code shows the network and copies its password; anything else is shown to copy | The QR camera that adds printers, `ReadCode` to make sense of what it says, and `LinkOpener` (the `url_launcher` plugin) to open a link | A phone's camera. The app does not join the Wi-Fi itself |
| 13 | **Make a QR code** | Tools: a link, some words, or a Wi-Fi network, printed large as a sign with a heading | `codeSheet` and `wifiCode` in `made_pages.dart`. A Wi-Fi password goes in the code and is never printed in words | Scanning the printed sign with another phone |
| 14 | **Turn a page** | A button on each page while reviewing a scan | `ScanCubit.rotate` writes a turned copy; a picture chosen from the phone is left as it was | A real photo's size on a phone |
| 15 | **Merge files** | Tools: choose PDFs and pictures; they open as pages in the scan's review screen, to reorder and save as one PDF | `ScanCubit.addFiles`: a picture is a page, a PDF is drawn a page at a time | A long PDF on a phone |
| 16 | **Take pages from a PDF** | Tools: the same screen. Remove the pages not wanted, save the rest | The same | The same |
| 17 | **Pages per sheet** | Tools: a PDF's pages two or four to a sheet | `pagesOnSheets` | How small text reads on paper |
| 18 | **Print a note** | Tools: type or paste words, with a heading, and print | `noteSheet` | A long note on paper |
| 19 | **Printable pages** | Tools: lined, squared, or dotted paper, a checklist, a month's calendar | `printableSheet`. Whole squares only; the calendar starts the week where the phone's region does | Ruling lines on paper |

Numbers 13, 17, 18, and 19 share one screen shape (`MakeScaffold`) and one kind of cubit (`MakeCubit`): say what to make, make it, print or share.

What these do not do, so nobody is surprised:

- Timestamp, watermark, and signature are for a scan saved as a PDF. They cannot be put on a PDF that came from somewhere else (see "Later").
- A signature is placed on one sheet. Signing several sheets means saving once per signature, which the app does not offer yet.
- A PDF brought in to merge, trim, or set several to a sheet is redrawn as pictures. It prints the same, but its words can no longer be selected, and the file is larger. The app says so on the screen.
- Words the app sets itself (a note, a sign's heading, a calendar) are in Manrope. Letters it does not have, such as some used in Yoruba and Vietnamese, are left out. A font with wider coverage would fix that.
- Passport-size is the common 35 by 45 mm. Other countries' sizes are part of "ID photo maker" below.

## Later: possible on the phone, bigger or with a catch

| Feature | The catch | Size |
|---|---|---|
| **Photo translation** | Reading the words exists. Translating them on the phone needs Google's on-device translation on Android and Apple's on iOS, each downloading a language pack of some tens of megabytes on first use. Which languages, and whether the download is acceptable, need deciding. To confirm against current documentation before starting | M to L |
| **ID photo maker** | Needs finding the face and cutting out the background on the phone (available on both platforms), then laying photos out at official sizes, which differ by country. The layout and printing fit this app well; the country rules are the work | L |
| **Book** (a two-page spread) | Splitting a spread down the middle is easy. Flattening the curve of a page is not, and without it the result is poor | M for the split only |
| **Sign or watermark any PDF**, not only scans | The app can make PDFs but cannot edit one that already exists. Doing it properly needs a PDF editing library, most of which are commercial. The route without one draws each page to a picture and rebuilds the PDF, which loses selectable text and makes the file larger | M, with that loss |
| **Searchable PDF** | Putting the recognised words invisibly behind the page picture, so the PDF itself can be searched. The words are already read; placing them needs their positions, which the two platforms report differently | M |

## Not on the phone alone

These are in the scanner app because it sends the document to its own servers. PrinterHub does not, by design.

| Feature | Why not |
|---|---|
| **To Word, To Excel, To PPT** | Rebuilding a document's layout, tables, and slides from a picture is done by a cloud service. Exporting the plain words as a text file is feature 1; a real Word or Excel file is not something the phone can produce well |
| **Formula** | Recognising handwritten or printed mathematics needs a specialised model that neither platform ships |
| **Smart erase, Erase marks** | Removing an object and filling in what was behind it needs an image-generation model |

If these ever matter, the honest path is a document-processing service the workspace opts into, with the privacy consequences stated. That is a product decision, not a small feature.

## What to do next

1. Run all nineteen on the iOS simulator against the printer simulator: Copy and Print photos first, since they send something to a printer.
2. Run them on an Android phone, with the camera, file sharing, and text reading that also wait for one.
3. Then choose from "Later". Searchable PDF and merging or reordering scans are the closest to what exists.
