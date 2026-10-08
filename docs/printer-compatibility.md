# Printer compatibility

What PrinterHub needs from a printer or scanner, what real devices do differently from the standards, and what the app does about each difference. Read this before changing `printerhub/packages/printer_protocols` or `connection_engine`, and before the first session with a new model of printer.

The app talks to devices itself, over the local network, with two protocols:

| Protocol | For | Devices that have it |
|---|---|---|
| IPP (`ipp://`, `ipps://`) | Printing, job tracking, status, supplies | Every AirPrint, Mopria, and IPP Everywhere printer: nearly every network printer sold since about 2013 |
| eSCL (`http(s)://…/eSCL`) | Scanning | Every AirPrint ("AirScan") and Mopria Scan device |

## What was verified, and how

| Claim | How it is checked |
|---|---|
| PWG Raster and Apple Raster files are correct | The encoder's output is compared byte for byte with what `rastertopwg`, the CUPS filter that ships with macOS, writes for the same pages. `test/fixtures/raster/` holds the reference files. |
| A printer can read what the encoder writes | `backend/simulator/raster.py` is a separate reader, tested against the same reference files. The simulator reads every raster job it is sent and counts its pages. |
| Digest sign-in is correct | The worked examples of RFC 7616 §3.9.1 (MD5 and SHA-256) are tests. |
| The clients work over real HTTP | `make app-simulator-test` runs them against `backend/simulator`, which can stand in for a printer without PDF, a printer that wants a password, a printer that only speaks IPP 1.1, a scanner that answers "busy", and a scanner that misnames itself. |
| Scanner quirks | Taken from `sane-airscan`, the SANE project's eSCL driver, which records what scanners in use need. |

**Not yet verified on hardware:** nothing here has been run against a physical printer. The checklist at the end is what to run first.

## Printing

### PDF cannot be taken for granted

IPP Everywhere requires a printer to accept PWG Raster, and JPEG if it prints colour. PDF is only recommended. Office printers such as the Xerox VersaLink read PDF; many home inkjets do not. AirPrint printers always accept Apple Raster (URF).

So the app asks the printer what it takes (`document-format-supported`) and chooses, in `choosePrintFormat`:

1. The file's own format, when the printer lists it: a PDF goes as PDF, a photo as JPEG.
2. PWG Raster, when the printer lists `image/pwg-raster` with a pixel layout the app draws (`srgb_8` or `sgray_8`).
3. Apple Raster, when the printer has AirPrint.
4. Nothing. The print screen then hands the document to the phone's own print dialog.

For raster, pages are drawn at 300 dpi when the printer offers it, otherwise the next resolution above it. `RasterEncoder` writes both formats a page at a time, so a long document never sits in memory whole.

**The back of a duplex sheet** has to be delivered the way the printer's paper path turns it. The printer says which in `pwg-raster-document-sheet-back` (`normal`, `flipped`, `rotated`, `manual-tumble`), or for Apple Raster in the `DM1` to `DM4` codes of `urf-supported` (`DM1` normal, `DM2` flipped, `DM3` rotated, `DM4` manual-tumble). The encoder turns back sides accordingly; callers pass every page upright.

On the phone, pages are drawn by `PrintingPageRenderer` (`printerhub/lib/print/platform/`), a page at a time, and the same class hands a document to the system print dialog.

### Other things printers insist on

| What | What the app does |
|---|---|
| Some printers cannot read a document sent without its size (chunked). | `printJob` requires the length and always sends `Content-Length`. |
| A printer may refuse a job only after megabytes have been sent. | `printJob` sends Validate-Job first. A printer too old to have it (`server-error-operation-not-supported`) is sent the job regardless. |
| Printers from before about 2010 only speak IPP 1.1. | A request refused with `server-error-version-not-supported` is sent again as 1.1, and the client stays on 1.1. |
| A tray or paper type is not a job attribute of its own. | They are sent inside `media-col`, with the paper's measurements. A request carries `media` or `media-col`, never both. |
| Printers answer at different paths. | The probe tries `/ipp/print` (the standard), then `/ipp/printer`, `/ipp`, and `/`. A path that was typed, or announced over Bonjour (`rp`), is the only one tried. |
| Printers present a self-signed certificate. | `CertificateTrust` remembers the certificate first seen for a host and refuses a different one later. Certificate checking is never switched off. |
| A printer may answer HTTP 426 on its open port. | The probe moves on to `ipps://`. |

### Printers that ask who is printing

A printer with IPP authentication switched on answers HTTP 401. On the Xerox VersaLink this is **Connectivity → AirPrint → IPP Authentication → Basic**.

- The client signs in with Digest (MD5 or SHA-256) or Basic. Digest is preferred, because it never sends the password.
- A Basic password is only sent over TLS. On an open connection the probe moves to the printer's `ipps://` address; when there is none, the app says to switch secure printing on.
- Sign-in happens on the Validate-Job that precedes a print, never while a document is being sent, because a document stream cannot be sent twice.
- The add-printer flow asks for the user name and password, and saves them with the printer's connection. The backend keeps them encrypted and gives them to members with the `connections.use_credentials` permission; each phone keeps what it read in its keystore, so the backend's audit log records one read per phone, not one per status check.

## Scanning

| What scanners do | What the app does |
|---|---|
| Answer 503 while the lamp moves or the page is still being scanned. | `startScan` asks again every second, up to 10 times; `nextDocument` up to 30 times. These are the limits `sane-airscan` uses. |
| Name the new job in `Location` with a host the phone cannot find, another port, or an address cut short (Xerox B205/B215 send `http://[fe80/eSCL/…`). | Only the path of `Location` is believed. The job is on the device the request went to. |
| Read the settings in order and ignore what is out of place. | `ScanSettings` is written in the order `sane-airscan` uses, as version 2.0. `DocumentFormatExt` is sent only to a scanner that lists its formats that way. |
| Refuse a resolution, colour mode, format, or area they did not offer. | `EsclInput.settings` fits what the person chose to what the scanner listed. |
| End a feeder scan with 404, or 410. | Both mean "no more pages". An empty feeder is no pages, not an error. |
| Give one page from the glass, then anything at all. | After the glass's page, any answer but another page ends the scan, without waiting. |

### What a scan is kept as

The app asks the scanner for a JPEG a page, which every eSCL scanner the standard describes can give, and writes each to a file as it arrives (`ScanRunner`). The phone puts the pages together as one PDF, at the paper size that was scanned (`assembleScan`), or keeps them as pictures when that was asked for.

- A scanner that only gives PDF is asked for PDF. Its pages are kept as the files it made, one each: the app does not merge PDFs.
- A picture the PDF writer cannot read does not lose the scan: the pages are kept as pictures.
- A scan that stops part way keeps the pages that arrived. A scan is never started a second time on another connection once the scanner has taken the job.
- When a scanner answers "not ready" (409), the app asks `ScannerStatus` why, and says whether the feeder is empty, jammed, or open.
- An ID card is two scans of one corner of the glass, 92 mm by 60 mm (`ScanPaper.card`): the card and a little around it. The two sides are laid on one sheet at that size, so a print matches the card. This relies on the scanner scanning only the area it is asked for, which eSCL requires and no hardware has confirmed yet. The simulator does not: it returns the same page whatever the area, so there the two sides come out as small pages. A scanner that returns the whole glass would print the card too small; that would be a fix in `assembleScan`, cutting the picture by its resolution.

Known models that need more, from `sane-airscan` (`EsclQuirks.forModel`). The app goes by the name the scanner gives itself in `ScannerCapabilities`, which is what that list is keyed on:

| Model (as `MakeAndModel`) | What it needs |
|---|---|
| Xerox `B205`, `B215`, `WorkCentre 3345` | Answer 404 or 410 while a page is on its way: those are retried like 503. |
| `RICOH` | Leaves the job pending until asked for `ScannerStatus` before each page. |
| `Brother …` | Loses feeder pages when asked for the next at once: a pause between pages, half the time the last one took and a second at most. |
| `HP LaserJet MFP M630`, `HP Color LaserJet FlowMFP M578` | Refuse a scan unless the request's `Host` is `localhost`. |

Known and not handled yet: the Kyocera ECOSYS M6526cdn closes its TLS connection before the body of the `ScanJobs` answer is complete; Canon iR2625/2630 advertise 600 dpi and only deliver 300; EPSON scanners want the port in `Host` even when it is 80.

## The Xerox VersaLink C7130

The reference device (FRD §62). From Xerox's specification sheet and System Administrator Guide:

- **Print languages:** PCL 5e/6, PDF, TIFF, JPEG, HP-GL; PostScript 3 optional. PDF goes to it as PDF.
- **Mobile printing:** AirPrint and Mopria Print. "AirPrint and all of required protocols are enabled by default." It needs HTTP, IPP, and mDNS on.
- **Mobile scanning:** Mopria Scan and AirPrint, which are both eSCL. Switched on in the Embedded Web Server; enabling Mopria scanning also enables AirPrint scanning. If eSCL does not answer, that switch is the first thing to check.
- **IPP:** port 631, with optional alternates 80 (IPP) and 443 (IPPS). Authentication is off by default and can be set to Basic.
- **HTTPS:** a self-signed certificate, made by the device.
- **Standard:** Ethernet, USB, NFC. **With the optional wireless kit:** Wi-Fi, Wi-Fi Direct (off by default), and Bluetooth as iBeacon only.
- **NFC:** Xerox supports it with Android only, and it hands over the network interface to reach the printer on. The app reads the tag on both platforms and uses what it holds.
- **Discovery across subnets** needs the network to pass multicast DNS. On another subnet, add the printer by address.

## First session with a real printer

Run these in order, and note the model and firmware beside each result.

1. Add by address. The model, colour, duplex, and scanner are described correctly.
2. Find it under "Nearby printers" on the same Wi-Fi.
3. Status: open a tray or a door and refresh. The alert appears, and clears.
4. Supplies: the toner levels match the printer's own panel.
5. `dart run` the smoke script against it (to be written with A3): Get-Printer-Attributes, and record `document-format-supported`, `pwg-raster-document-*`, `urf-supported`, `uri-authentication-supported`, and `ipp-versions-supported`.
6. Print a one-page PDF. Then two pages on both sides, long edge and short edge: the back is the right way up.
7. Print the same pages as PWG Raster and as Apple Raster, on a printer that lists them.
8. Scan from the glass, kept as a PDF and as a picture. Scan three sheets from the feeder, and both sides of them. Scan with the feeder empty. Note what `ScannerCapabilities` lists for `DocumentFormat`, and whether a JPEG scan from the feeder gives one page per request. Scan an ID card with the ID card switch on, print the PDF at full size, and lay the card on the print: it should match, and the corner the app names should be the corner the scanner starts from.
9. Switch on IPP authentication, add the printer again, and print.
10. Switch on HTTPS-only, and repeat 1 and 6.
11. On a phone: NFC tap, QR code, and Bluetooth sighting, none of which has run on hardware.

## Sources

- IPP Everywhere, PWG 5100.14: <https://www.pwg.org/ipp/everywhere.html>
- PWG Raster Format, PWG 5102.4: <https://ftp.pwg.org/pub/pwg/candidates/cs-ippraster10-20120420-5102.4.pdf>
- CUPS, for Apple Raster and how `urf-supported` and sheet-back are read (`cups/raster-stream.c`, `cups/ppd-cache.c`): <https://github.com/OpenPrinting/cups>
- `sane-airscan`, for eSCL behaviour and scanner quirks (`airscan-escl.c`): <https://github.com/alexpevzner/sane-airscan>
- HTTP Digest, RFC 7616: <https://www.rfc-editor.org/rfc/rfc7616>
- Xerox VersaLink C7120/C7125/C7130 Detailed Specifications: <https://www.office.xerox.com/latest/VC7SS-02.pdf>
- Xerox VersaLink Series System Administrator Guide: <https://download.support.xerox.com/pub/docs/VLB71XX/userdocs/any-os/en_GB/VersaLink_series_sag_en-US.pdf>
- Flutter and cleartext HTTP to local devices: <https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android>

The Mopria eSCL specification is public but sits behind a licence agreement to accept: <https://mopria.org/spec-download>. It was not used.
