# Printer simulator

A fake Xerox VersaLink C7130 that speaks IPP and eSCL. Use it to build and test a client's printing, scanning, status, and fallback logic without the hardware.

```bash
make simulator          # http://localhost:8631
```

From a phone or emulator, use your computer's LAN address instead of `localhost`, and add the printer by IP. The simulator does not advertise itself over mDNS, so automatic discovery will not find it.

## Endpoints

| Protocol | Endpoint | Notes |
|---|---|---|
| IPP | `POST /ipp/print` | Body and response are `application/ipp`. Get-Printer-Attributes, Validate-Job, Print-Job, Get-Job-Attributes, Get-Jobs, Cancel-Job. |
| eSCL | `GET /eSCL/ScannerCapabilities` | Platen and document feeder, 150 to 600 DPI, PDF and JPEG. |
| eSCL | `GET /eSCL/ScannerStatus` | Scanner and feeder state, running jobs. |
| eSCL | `POST /eSCL/ScanJobs` | Starts a scan; the job URL comes back in `Location`. |
| eSCL | `GET /eSCL/ScanJobs/{id}/NextDocument` | One page per call, then `404`. A JPEG scan gives a small picture of a page; a PDF scan a one-page PDF. |
| eSCL | `DELETE /eSCL/ScanJobs/{id}` | Cancels a scan. |
| Control | `GET`, `PATCH /sim/state` | Inspect and change the simulated device. |
| Control | `POST /sim/reset` | Back to factory state. |

Interactive docs: <http://localhost:8631/docs>.

## Behavior worth knowing

- **IPP errors arrive inside HTTP 200.** That is how IPP works: read the status code in the IPP response, not the HTTP status.
- **Print jobs take time.** A job is `pending`, then `processing`, then `completed` over `job_duration_seconds` (default 4). Poll Get-Job-Attributes to watch it.
- **A feeder scan has several pages.** Call `NextDocument` until it returns `404`. A platen scan has one page.
- **Scanned pages are generated.** PDF pages carry a line of text saying which page they are; JPEG pages are a small grey picture of a page, 248 by 350.
- **Raster print jobs are read.** A job sent as `image/pwg-raster` or `image/urf` is decoded the way a printer would. One that is cut short, or is the other format under the wrong name, is refused with `client-error-document-format-error`. The page count appears in `/sim/state` and as `job-impressions`.

## Injecting faults

```bash
curl -X PATCH localhost:8631/sim/state -H 'content-type: application/json' \
  -d '{"faults": {"paper_jam": true}}'
```

| Fault | Effect |
|---|---|
| `offline` | IPP answers `server-error-service-unavailable`; eSCL answers `503`. |
| `paper_jam` | New print jobs stop in `processing-stopped`; `printer-state-reasons` has `media-jam-error`; feeder scans are refused. Clearing it lets stopped jobs finish. |
| `door_open` | Print-Job is refused; `printer-is-accepting-jobs` is false. |
| `adf_empty` | Feeder scans are refused with `409`; platen scans still work. |
| `escl_disabled` | Every eSCL endpoint answers `404`, like firmware that does not expose eSCL. Use it to test the scan fallback order (FR-MOB-007). |
| `ipp_1_1_only` | IPP 2.0 requests are refused with `server-error-version-not-supported`, like a printer from before 2010. |

Other knobs in the same `PATCH`: `toner` (percent per colour; 10 or less reports low, 0 reports empty), `job_duration_seconds`, `adf_pages`.

## Standing in for other printers

A client that only meets a Xerox that reads PDF will fail on the printer at home. These knobs make the simulator behave like the others:

| Knob | Effect |
|---|---|
| `document_formats` | What the printer accepts. `["image/pwg-raster", "image/urf", "image/jpeg"]` is a printer that does not read PDF; `["image/urf"]` is one with AirPrint alone. |
| `auth` | `"basic"` or `"digest"`: IPP answers `401` until the request is signed in as `auth_user` / `auth_password`. |
| `scan_busy_responses` | Each scanned page answers `503` that many times before it arrives, as a scanner does while its lamp moves. |
| `scan_location` | How a new scan job is named in `Location`: `"absolute"`, `"path"`, or `"wrong_host"` (a name the client cannot look up). |

`docs/printer-compatibility.md` says why each of these matters.

## Trying the fallback flow

1. Add the simulator to PrinterHub with an IPP connection and an eSCL connection.
2. `PATCH` `{"faults": {"offline": true}}`.
3. Print from the client. It should try IPP, fail, move to its next connection, and report the job with `fallback_occurred: true`.
