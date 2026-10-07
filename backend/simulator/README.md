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
| eSCL | `GET /eSCL/ScanJobs/{id}/NextDocument` | One page per call, then `404`. |
| eSCL | `DELETE /eSCL/ScanJobs/{id}` | Cancels a scan. |
| Control | `GET`, `PATCH /sim/state` | Inspect and change the simulated device. |
| Control | `POST /sim/reset` | Back to factory state. |

Interactive docs: <http://localhost:8631/docs>.

## Behavior worth knowing

- **IPP errors arrive inside HTTP 200.** That is how IPP works: read the status code in the IPP response, not the HTTP status.
- **Print jobs take time.** A job is `pending`, then `processing`, then `completed` over `job_duration_seconds` (default 4). Poll Get-Job-Attributes to watch it.
- **A feeder scan has several pages.** Call `NextDocument` until it returns `404`. A platen scan has one page.
- **Scanned pages are generated.** PDF pages carry a line of text saying which page they are; JPEG pages are a 1×1 image.

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

Other knobs in the same `PATCH`: `toner` (percent per colour; 10 or less reports low, 0 reports empty), `job_duration_seconds`, `adf_pages`.

## Trying the fallback flow

1. Add the simulator to PrinterHub with an IPP connection and an eSCL connection.
2. `PATCH` `{"faults": {"offline": true}}`.
3. Print from the client. It should try IPP, fail, move to its next connection, and report the job with `fallback_occurred: true`.
