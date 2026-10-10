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
| Extract text | The words of a scan are read on the phone when it is kept in the workspace, and Documents finds it by them. There is no screen that shows the text yet (see "Build next") |
| Import files | "Print a file" picks a PDF, JPEG, or PNG. A file shared or opened from another app opens in PrinterHub |
| Scan with the phone's camera | Scan screen, and now Home, with no printer needed. Written and unit-tested; not yet run on a phone |
| Print what was scanned | "Print it" on a finished scan |
| Keep, find, rename, delete documents | Documents, under Activity and on Home |

## Build next: works with what the app already has

These need no new service and no new kind of permission. Each reuses something that exists.

| # | Feature | What the person gets | How it is built | Size | Proved on |
|---|---|---|---|---|---|
| 1 | **Extract text** as a tool | Pick a picture, a PDF, or a scan; see its words; copy them or share them as a text file | `ScanTextReader` already reads pictures. A PDF is drawn to pictures first with `PageRenderer`. One new screen | S | iOS simulator; Android phone |
| 2 | **Pictures to PDF** (Import Images) | Pick several photos, put them in order, get one PDF to print, share, or keep | The picker learns to pick several. They join the scan's review screen as pages; `assembleScan` makes the PDF | S | iOS simulator |
| 3 | **PDF to pictures** | A PDF's pages as JPEGs, to share | `PageRenderer` draws each page; the share sheet takes the files | S | iOS simulator |
| 4 | **PDF to one long picture** | Every page stacked into one tall image, for sending in a chat | The same drawing, joined top to bottom. Capped at a sensible number of pages | S | iOS simulator |
| 5 | **ID card with the camera** | The ID card layout without a printer's glass | The camera gives a straightened picture of each side. `assembleScan` lays them two to a sheet. The card's true size is not known from a photo, so both sides are fitted to the standard card size | S | Android phone |
| 6 | **Timestamp** | The date and time, and optionally a note, printed on a page or photo | Drawn onto the page when the PDF is made (`assembleScan`), not burned into the original | S | iOS simulator |
| 7 | **Watermark** | A word such as COPY or DRAFT across each page of a scan | The same place as the timestamp: text drawn over each page at an angle, pale | S | iOS simulator |
| 8 | **Sign** | Draw a signature once, keep it on the phone, place it on a page of a scan | A drawing pad saves the signature as a picture in the phone's secure storage. Placing it is dragging it over the page before the PDF is made | M | iOS simulator |
| 9 | **Page clean-up** (Whiteboard, Slides) | A scan mode that makes pen on a whiteboard, or a projected slide, crisp: brighter background, stronger lines | An image filter applied to each page before the PDF is made, with "Original" always one tap away. Three filters to start: Document, Whiteboard, Black and white | M | iOS simulator |
| 10 | **Copy** | One button: scan on this printer and print the result on it (or another), with the number of copies | It is scan, then print, which both exist. The API already has a copy job to record it as one thing | M | Printer simulator |
| 11 | **Print photos** | Pick photos, choose a size (10×15, 13×18, passport sheet) and how many to a sheet | Pages laid out with the PDF writer at the paper's true size, then the normal print | M | Printer simulator |

Numbers 1 to 4 and 6 to 7 are small and independent: they could ship together as a "Tools" section on Home. Number 10 is the one the product requirements already ask for (FR-CPY).

## Later: possible on the phone, bigger or with a catch

| Feature | The catch | Size |
|---|---|---|
| **Photo translation** | Reading the words exists. Translating them on the phone needs Google's on-device translation on Android and Apple's on iOS, each downloading a language pack of some tens of megabytes on first use. Which languages, and whether the download is acceptable, need deciding. To confirm against current documentation before starting | M to L |
| **ID photo maker** | Needs finding the face and cutting out the background on the phone (available on both platforms), then laying photos out at official sizes, which differ by country. The layout and printing fit this app well; the country rules are the work | L |
| **Book** (a two-page spread) | Splitting a spread down the middle is easy. Flattening the curve of a page is not, and without it the result is poor | M for the split only |
| **Sign or watermark any PDF**, not only scans | The app can make PDFs but cannot edit one that already exists. Doing it properly needs a PDF editing library, most of which are commercial. The route without one draws each page to a picture and rebuilds the PDF, which loses selectable text and makes the file larger | M, with that loss |
| **Merge, split, reorder, rotate PDFs** | The same limit: fine for scans, lossy for PDFs from elsewhere | M |
| **Searchable PDF** | Putting the recognised words invisibly behind the page picture, so the PDF itself can be searched. The words are already read; placing them needs their positions, which the two platforms report differently | M |

## Not on the phone alone

These are in the scanner app because it sends the document to its own servers. PrinterHub does not, by design.

| Feature | Why not |
|---|---|
| **To Word, To Excel, To PPT** | Rebuilding a document's layout, tables, and slides from a picture is done by a cloud service. Exporting the plain words as a text file is feature 1; a real Word or Excel file is not something the phone can produce well |
| **Formula** | Recognising handwritten or printed mathematics needs a specialised model that neither platform ships |
| **Smart erase, Erase marks** | Removing an object and filling in what was behind it needs an image-generation model |

If these ever matter, the honest path is a document-processing service the workspace opts into, with the privacy consequences stated. That is a product decision, not a small feature.

## What to build first

A suggested order, smallest and most useful first:

1. **Extract text**, **Pictures to PDF**, **PDF to pictures**: three small tools that make Home's tools section worth opening.
2. **Copy**: the requirement the product already has, and the reason someone stands at a printer.
3. **Timestamp** and **Watermark**: one piece of work, since they are drawn in the same place.
4. **Sign**, then **Page clean-up**.
5. **Print photos**.

Each is added the way the app's rules say: a tile appears on Home only when the thing it starts works, the feature sits behind a workspace switch where the backend has one, and nothing is called done before it has run on a phone.
