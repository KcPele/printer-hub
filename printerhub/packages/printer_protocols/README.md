# printer_protocols

IPP and eSCL in pure Dart. This is how the app talks to a printer or scanner on the local network. No Flutter, so it runs in plain unit tests.

```dart
final http = IoPrinterHttp();

final printer = IppClient.forHost('192.168.1.40', http: http);
final about = await printer.getPrinterAttributes();
final job = await printer.printJob(
  document: file.openRead(),
  length: await file.length(),
  options: const IppJobOptions(copies: 2, sides: 'two-sided-long-edge'),
);

final scanner = EsclClient.forHost('192.168.1.40', http: http);
final scan = await scanner.startScan(const EsclScanSettings(fromFeeder: true));
while (true) {
  final page = await scanner.nextDocument(scan);
  if (page == null) break;
  await page.bytes.pipe(pageFile.openWrite());
}
```

## What is here

| Part | Does |
|---|---|
| `IppClient` | Get-Printer-Attributes, Validate-Job, Print-Job, Get-Job-Attributes, Get-Jobs, Cancel-Job |
| `encodeIpp` / `decodeIpp` | The binary format, including collections |
| `IppPrinterAttributes` | The printer's answer as typed getters: state, media, supplies, and so on |
| `EsclClient` | ScannerCapabilities, ScannerStatus, ScanJobs, NextDocument, cancel |
| `IoPrinterHttp` | The network. Tests use `FakePrinterHttp` from `testing.dart` instead |

## Failures

| Thrown | Means |
|---|---|
| `PrinterUnreachable` | No answer: off, another network, timed out, or a certificate that was not accepted |
| `IppNotAvailable` | Something answered, but not with IPP: wrong path, needs TLS, needs a password |
| `IppException` | The printer understood and refused, or failed. IPP errors arrive inside HTTP 200 |
| `EsclException` | The scanner answered with an error. `notSupported`, `busy`, and `notReady` say which kind |

## Documents are streamed

A document to print and a scanned page are streams, never whole in memory.

## Self-signed certificates

Every printer signs its own certificate. `IoPrinterHttp` refuses those unless given a `certificateCheck`, which receives the certificate's SHA-256 fingerprint and decides. Checking is never switched off for everything.

## Tests

```sh
dart test                    # everything that needs no device
make simulator               # in another terminal: a fake Xerox VersaLink C7130
dart test --tags simulator   # the clients against it, faults included
```

`test/fixtures/test_only_*.pem` is a certificate made for the tests, standing in for a printer's. It protects nothing.
