# PrinterHub — Functional Requirements Document (FRD)

**Document version:** 2.0  
**Status:** Draft — Backend-First / Mobile-First Product Definition  
**Product type:** Cross-platform printer and scanner management platform  
**Primary production client:** PrinterHub Mobile for iOS and Android  
**Secondary client:** Responsive Web App / Progressive Web App (PWA) consuming the same backend  
**Backend strategy:** API-first shared backend completed before broad client rollout  
**Optional enterprise component:** PrinterHub Gateway for locations that later require always-on or browser-only local execution  
**Initial target device:** Xerox VersaLink C7130 / C7100 Series  
**Long-term target:** Multi-vendor printers and multifunction devices

**Revision 2.0 focus:** Makes the mobile application a first-class product and the primary local printer execution layer. The backend becomes the shared source of truth for mobile and web clients. Mobile receives the richer connection stack—native LAN discovery, AirPrint/Android printing, direct IPP/IPPS, eSCL/AirScan where supported, Wi-Fi Direct, NFC, QR, BLE/iBeacon discovery, Android USB where feasible, local network telemetry, camera document capture, and automatic connection fallback. The Web/PWA remains a full client for administration, documents, history, and browser-supported printing/scanning, but is not required to match native mobile hardware access.  

---

## 1. Product Summary

PrinterHub is a **backend-first, mobile-first** platform that makes printing, scanning, copying, printer discovery, device monitoring, and document routing simple without requiring users to understand printer networking.

The first production client is the **PrinterHub Mobile App**. The phone or tablet acts as the user's local printer connector: it communicates directly with printers that are reachable over the user's office/home network, Wi-Fi Direct, supported native print frameworks, NFC/QR-assisted pairing, and other mobile-accessible methods.

The shared PrinterHub backend provides authentication, organizations, printer profiles, job metadata, document services, presets, notifications, audit logs, integrations, and synchronized state. The backend is **not expected to directly reach private LAN printers** during normal mobile use; local printer execution happens on the user's device.

The later Web/PWA consumes the same backend and provides the same account, printers, documents, presets, history, organization settings, and browser-supported print/scan flows. When a browser cannot access a hardware capability that the mobile app can, the UI must state that limitation rather than pretending feature parity.

The defining product requirement is **multi-mode connectivity with graceful fallback**. A user should be able to install PrinterHub, discover or pair a printer using the easiest available method, and let the app choose a working transport.

Typical experience:

1. Install PrinterHub Mobile and sign in or continue in permitted local mode.
2. Grant local-network / nearby-device permissions when needed.
3. Tap **Add Printer**.
4. PrinterHub discovers nearby compatible printers or offers IP, QR, NFC, Wi-Fi Direct, and other supported methods.
5. PrinterHub probes capabilities and records one logical printer with several possible connection paths.
6. User selects Print, Scan, Copy, or another action.
7. PrinterHub uses the preferred connection and automatically tries an approved fallback if that route fails.
8. Job state is synchronized to the shared backend when online.

The product should abstract technical protocols and platform APIs such as IPP/IPPS, AirPrint, Android Print Framework/Mopria-compatible flows, eSCL/AirScan, mDNS/Bonjour, DNS-SD, Wi-Fi Direct, NFC, BLE/iBeacon, HTTP/HTTPS device APIs, SNMP, SMB/SFTP, USB, and vendor-specific interfaces behind a simple user interface.

---

## 2. Product Goals

PrinterHub must:

- Make **mobile installation the only required end-user installation** for the primary product experience.
- Provide one simple interface for printing, scanning, copying, printer management, and document routing.
- Build a complete, versioned backend API that both mobile and web clients consume.
- Make the mobile app the richer hardware-facing client when native OS APIs provide capabilities browsers cannot reliably access.
- Support multiple ways to connect to the same physical printer.
- Automatically discover and probe printer capabilities where technically possible.
- Automatically select the best available connection without asking non-technical users to choose protocols.
- Make manual fallback easy when automatic fallback cannot safely determine a working route.
- Keep local printer operations usable when cloud connectivity is unavailable, where the selected connection permits it.
- Synchronize printer profiles, presets, job history, organizations, and user settings when cloud connectivity returns.
- Avoid requiring an on-premises server, desktop agent, or Docker installation for normal mobile use.
- Avoid exposing printers directly to the public internet.
- Support homes, offices, print shops, schools, and organizations.
- Support multiple printer vendors over time through a normalized capability and adapter layer.
- Allow the later Web/PWA to reuse the same backend and business rules rather than becoming a separate product.
- Protect document privacy by allowing direct/local execution modes in which document bytes do not have to be stored in PrinterHub cloud.

---

## 3. Non-Goals for Initial Release

The initial release does not need to:

- Replace manufacturer firmware.
- Provide hardware-component repair diagnostics.
- Guarantee every advanced vendor-specific finishing option.
- Support legacy printers that expose no usable network, native OS, or supported direct interface.
- Bypass operating-system or browser security restrictions.
- Require a PrinterHub Gateway/Local Agent for ordinary mobile users.
- Treat Bluetooth/iBeacon as a print-data transport unless a specific printer exposes a documented compatible data service.
- Assume every Xerox C7130 has Wi-Fi, Wi-Fi Direct, or Bluetooth hardware installed; these capabilities must be detected because Xerox lists them with the optional wireless kit.
- Promise generic direct USB printing/scanning on iPhone/iPad; direct USB support must be platform- and device-capability-gated.
- Make the Web/PWA match every native mobile capability where browser sandboxing prevents equivalent access.

---

## 4. User Types

### 4.1 Personal User

A user with one or several home/office printers who wants simple printing and scanning.

### 4.2 Office User

An employee who uses shared printers and scanners and needs presets, scan destinations, and job history.

### 4.3 Office Administrator

A user responsible for configuring printers, permissions, defaults, consumables, and troubleshooting.

### 4.4 Print Shop Operator

A user who receives many files, manages queues, changes print settings frequently, and tracks job status.

### 4.5 Organization Administrator

A user responsible for multiple locations, users, devices, access controls, and audit logs.

---

## 5. Supported Platforms

### 5.1 Primary Mobile Platforms

PrinterHub Mobile must target:

- Android phones and tablets
- iPhone
- iPad

The mobile client must be designed around native permissions and capabilities including:

- local network access
- Wi-Fi / nearby Wi-Fi devices
- Bonjour / DNS-SD or equivalent service discovery
- NFC where supported
- Bluetooth Low Energy / iBeacon discovery where supported
- camera access for QR pairing and document capture
- file picker / share sheet
- secure credential storage
- local notifications and push notifications
- native printing frameworks
- direct local HTTP(S) networking to printer IPs

### 5.2 Web Platforms

The PrinterHub Web/PWA should support:

- Google Chrome
- Microsoft Edge
- Safari
- Firefox where supported
- Windows
- macOS
- Linux
- Android browsers
- iOS/iPadOS browsers

The Web/PWA should be installable where PWA support permits.

### 5.3 Optional Future Gateway Platforms

An optional PrinterHub Gateway may later support:

- Linux / Docker
- Windows
- macOS
- NAS or small appliance deployments

The gateway is **not required** for the primary mobile workflow.

---

## 6. System Components

### 6.1 PrinterHub Backend

The backend is the shared platform foundation and must be implemented as an API-first system before broad client rollout.

It is responsible for:

- authentication and session management
- organizations, teams, roles, and permissions
- registered mobile/web devices
- logical printer profiles
- printer capability snapshots
- connection-profile metadata
- print/scan/copy job metadata and state
- idempotency and duplicate-job protection
- document metadata and optional encrypted object storage
- presets and workflow templates
- audit logs
- notifications
- APNs/FCM push orchestration
- email and cloud-storage integrations
- usage analytics
- feature flags and vendor capability profiles
- API versioning
- OpenAPI/contract documentation
- WebSocket/SSE real-time updates where appropriate
- signed upload/download flows
- optional remote relay/gateway coordination

The backend must distinguish between:

**Local execution jobs:** the mobile/web client talks directly to the printer and reports job state to the backend.

**Cloud-mediated jobs:** document data or job instructions intentionally pass through PrinterHub services for features such as cloud documents, integrations, or a future gateway.

### 6.2 PrinterHub Mobile

PrinterHub Mobile is the first production client and primary hardware-facing interface.

It is responsible for:

- automatic local printer discovery
- manual printer IP/hostname connection
- native print framework integration
- direct IPP/IPPS communication where useful
- direct eSCL/AirScan probing and scanning where the printer supports it
- Wi-Fi Direct workflows
- QR pairing
- NFC tap-to-pair / metadata reading where supported
- BLE/iBeacon proximity discovery where supported
- Android Wi-Fi P2P APIs where compatible
- Android USB-host access where a supported printer/driver path exists
- direct local printer status queries where permitted
- scan acquisition and streamed file reception
- camera document capture as a fallback/document-ingestion method
- local OCR and document editing
- offline printer profiles and presets
- local job queue and retry
- secure local credential storage
- automatic connection fallback
- background-safe synchronization with the backend
- native share/open-in flows

The mobile application should hide connection complexity. The preferred UX is **Find printer → tap printer → use it**.

### 6.3 PrinterHub Web/PWA

The Web/PWA is the second client and consumes the same backend.

It provides:

- sign-in and organizations
- printer inventory
- documents
- job history
- presets
- administration
- analytics
- monitoring
- browser-supported printing/scanning
- native browser print-dialog fallback
- direct browser IPP/eSCL only where CORS, TLS, permissions, and browser networking allow it

The Web/PWA must use shared backend contracts and normalized printer models. It must not implement a separate incompatible job model.

### 6.4 Printer Protocol / Capability Layer

Both clients should use a normalized capability model.

Possible adapters include:

- Generic IPP/IPPS
- AirPrint/native iOS printing
- Android Print Framework
- Mopria-compatible discovery/scan behavior where available through supported APIs or direct protocols
- eSCL/AirScan
- mDNS/Bonjour/DNS-SD
- HTTP/HTTPS device/EWS interfaces
- SNMP where platform networking permits
- Wi-Fi Direct
- NFC/QR pairing
- BLE/iBeacon discovery
- vendor-specific adapters

A feature must be enabled from detected capability data rather than from model-name assumptions alone.

### 6.5 Optional PrinterHub Gateway

PrinterHub Gateway is an optional future component for organizations that want:

- browser-only staff access with no mobile executor
- always-on print/scan execution
- centralized office discovery
- desktop-driver integration
- CUPS/TWAIN/WIA/SANE access
- raw socket or SNMP functions unavailable to browser/mobile clients
- remote printing when no authorized mobile device is present

The gateway is not part of the required first mobile deployment.

### 6.6 Cloud Relay

The cloud relay is optional and should be used only when a remote workflow needs it.

No design should require inbound public access to a physical printer.

---

## 7. Mobile Application Requirements

### FR-MOB-001 — Mobile App as Local Executor

When the user is physically or logically on a network that can reach the printer, the mobile app should execute supported print/scan/status operations directly against the printer.

The cloud backend should coordinate identity and state but must not be required to route every local document through the cloud.

### FR-MOB-002 — Permission Onboarding

PrinterHub must request permissions contextually and explain why they are needed.

Possible permissions include:

- local network
- nearby Wi-Fi devices
- Bluetooth
- NFC
- camera
- photos/files
- notifications

The app should not ask for unrelated permissions at first launch.

### FR-MOB-003 — Automatic LAN Discovery

On supported mobile platforms, PrinterHub should use native service-discovery APIs to locate printers using technologies such as:

- Bonjour / mDNS
- DNS-SD
- IPP service advertisements
- IPPS service advertisements
- scanner/eSCL service advertisements where exposed

Discovered results should be de-duplicated into logical printers.

### FR-MOB-004 — Manual IP Connection

The user must be able to add a printer by IPv4, IPv6, hostname, or local DNS name.

PrinterHub should probe the host and identify which supported services respond.

### FR-MOB-005 — Native iOS/iPadOS Printing

On Apple mobile platforms, PrinterHub should support the native AirPrint print flow for compatible printers.

Where the OS owns the final print UI, PrinterHub should pass the prepared document and allow iOS/iPadOS to handle supported printer discovery and job submission.

PrinterHub may additionally use direct IPP/IPPS for capabilities that can be safely and reliably controlled outside the native print sheet.

### FR-MOB-006 — Native Android Printing

On Android, PrinterHub should integrate with the Android printing framework and compatible installed print services.

PrinterHub should also support direct IPP/IPPS where doing so provides a smoother in-app workflow and the printer supports it.

### FR-MOB-007 — Mobile Scanning

PrinterHub should attempt the richest available scan path in this order, subject to capability detection:

1. direct eSCL/AirScan-compatible scan path
2. compatible native/vendor scanning route
3. configured network scan destination / retrieval flow
4. camera document scan as an ingestion fallback

The app must distinguish a **printer scanner scan** from a **phone camera scan**.

### FR-MOB-008 — Wi-Fi Direct

Where the printer has Wi-Fi Direct enabled:

- Android should use native Wi-Fi P2P functionality where compatible and permitted.
- On iOS/iPadOS, PrinterHub may guide the user through joining the printer's Wi-Fi Direct network when automatic programmatic connection is not available.
- After the network link exists, PrinterHub should use IPP/IPPS/eSCL/HTTP as appropriate.

Wi-Fi Direct must be treated as a network path, not a separate print language.

### FR-MOB-009 — NFC Pairing

Where supported, tapping the phone on an NFC-enabled printer should help identify or configure the printer.

Possible uses:

- read printer/network metadata
- match a discovered printer
- open a pairing deep link
- bootstrap Wi-Fi Direct or LAN setup

NFC must not be assumed to carry print document payloads.

### FR-MOB-010 — BLE / iBeacon Proximity

PrinterHub may use BLE/iBeacon signals to identify a nearby compatible printer.

For the Xerox VersaLink C7130, Xerox documents Bluetooth as **iBeacon** with the optional wireless kit; therefore BLE must be treated primarily as proximity/discovery, not as the main print or scan transport.

### FR-MOB-011 — QR Pairing

The mobile app must support QR pairing using the camera.

QR payloads may contain:

- PrinterHub printer ID
- printer IP/hostname
- model
- optional local service endpoints
- organization/location
- short-lived pairing token

QR payloads must not expose long-lived administrative credentials.

### FR-MOB-012 — Android USB Host Mode

On Android devices with USB host/OTG support, PrinterHub may offer a direct USB mode when:

- the connected printer is supported
- the Android device grants USB permission
- the required printer protocol/driver path is available

This is an optional capability and must not block the normal network experience.

### FR-MOB-013 — iOS Direct USB Constraint

PrinterHub must not promise generic USB printer/scanner control on iPhone/iPad.

If Apple platform APIs and a specific supported accessory path make a USB workflow possible, it may be added as a capability-gated feature.

### FR-MOB-014 — Share Into PrinterHub

Users should be able to send a document into PrinterHub from another app using native share/open-in mechanisms.

Examples:

- Files
- Photos
- Mail
- browser downloads
- messaging apps
- cloud storage apps

The incoming file should open directly into Print Preview or Document Inbox.

### FR-MOB-015 — Share Scans Out

A completed scan should be shareable using the native share sheet without forcing the user to upload it to PrinterHub cloud first.

### FR-MOB-016 — Camera Document Capture

PrinterHub Mobile should include phone-camera document capture for situations where:

- the physical scanner is unavailable
- the user only needs a quick digital copy
- the scan must be captured before printing

Capabilities should include:

- auto edge detection
- perspective correction
- crop
- rotation
- multi-page capture
- contrast/cleanup
- PDF creation
- optional local OCR

### FR-MOB-017 — Offline Local Mode

Previously paired local printers should remain available for supported local print/scan actions when the internet is unavailable.

Cloud-only functions should be visibly marked unavailable and synchronize later.

### FR-MOB-018 — Secure Mobile Storage

Sensitive tokens and credentials must use platform secure storage such as Keychain/Keystore-backed mechanisms.

Printer passwords must not be stored in plaintext app preferences.

### FR-MOB-019 — Background and Foreground Job Behavior

PrinterHub must account for mobile OS background restrictions.

Long-running scans, uploads, or job monitoring should use supported background-task APIs where available. If the OS may suspend the app, the job state must recover safely when the user returns.

### FR-MOB-020 — Push Notifications

The backend should support APNs/FCM push notifications for events such as:

- job completed
- job failed
- scan ready
- printer unavailable
- organization invitation
- document shared

### FR-MOB-021 — Connection Quality UI

The mobile printer details screen should show a simple connection summary, for example:

```text
Office Xerox C7130
Online

Best connection: Local Network
Print: AirPrint / IPP
Scan: Direct Scan
Nearby: NFC available
Backup: Wi-Fi Direct

[ Print ] [ Scan ] [ Copy ]
```

Technical protocol names may be available under an Advanced section.

### FR-MOB-022 — Platform-Aware Fallback

Fallback order must be platform aware.

Example:

**iPhone/iPad printing**
1. direct app-managed IPP/IPPS where validated
2. AirPrint native print flow
3. Wi-Fi Direct + AirPrint/IPP after user joins the printer network
4. another saved printer

**Android printing**
1. direct IPP/IPPS where validated
2. Android Print Framework / installed Mopria-compatible print service
3. Wi-Fi Direct + IPP
4. supported USB OTG path
5. another saved printer

Scanning fallback should similarly prefer real printer scanning before camera capture.

---

## 8. Connection Modes

PrinterHub must support multiple connection modes per printer.

### FR-CON-001 — Automatic Network Discovery

The user must be able to search the local network for compatible printers.

The system should use discovery methods available to the current platform, such as:

- mDNS / Bonjour
- DNS-SD
- IPP/IPPS advertisements
- scanner/eSCL service advertisements where exposed
- Android nearby Wi-Fi / Wi-Fi P2P discovery where relevant
- BLE/iBeacon proximity discovery where supported
- NFC-assisted identification
- operating-system printer discovery
- SNMP or vendor discovery only on platforms where local networking permits it
- PrinterHub Gateway discovery if an optional gateway exists

The user should see:

- printer name
- manufacturer
- model
- IP address where available
- connection type
- online/offline state
- detected capabilities

### FR-CON-002 — Manual IP Address

The user must be able to add a printer by:

- IPv4 address
- IPv6 address
- hostname
- local DNS name

The app should test supported services and report what is available.

Example tests may include:

- IPP
- IPPS
- HTTP/HTTPS device page
- SNMP
- SMB scan path
- supported vendor interfaces

### FR-CON-003 — USB Connection

USB support is platform-specific.

On Android, PrinterHub may support compatible printers through USB host/OTG when the required protocol path is available.

On iOS/iPadOS, generic direct USB printer/scanner control must not be assumed.

A future PrinterHub Gateway/Desktop Agent may provide broader USB, TWAIN/WIA/SANE, or OS-driver access.

When USB is available, PrinterHub should detect:

- device name
- vendor/product identifiers
- supported printer/scanner functions
- permission state
- connection state

### FR-CON-004 — Operating-System / Native Print Connection

PrinterHub should use the native printing facilities available on each platform.

Examples:

- iOS/iPadOS AirPrint print UI
- Android Print Framework / installed print service
- Windows print subsystem in future desktop/gateway contexts
- macOS printing system in future desktop/gateway contexts
- Linux CUPS in future gateway contexts

### FR-CON-005 — Wi-Fi Direct

PrinterHub should support workflows where the user's device is connected directly to a printer's Wi-Fi Direct network.

The app should:

- explain when Wi-Fi Direct is detected or required
- help the user verify connectivity
- discover the printer on the direct network where possible
- retain a saved printer profile after connection

### FR-CON-006 — Optional Gateway / Desktop Agent Connection

The mobile app does not require a Local Agent for normal use.

If an organization later deploys PrinterHub Gateway/Desktop Agent, mobile and web clients may detect or select it as an additional execution path.

The UI may display:

- gateway/agent status
- host name
- version
- supported features
- last seen time
- connected printers

### FR-CON-007 — Cloud Relay / Remote Printer

A user must be able to register a printer or gateway for secure remote access.

The relay should allow approved remote operations such as:

- submit print job
- view printer status
- view queue
- receive completed scans
- receive error notifications

Remote scanning must only be enabled when the local device/workflow supports safe remote initiation.

### FR-CON-008 — Multiple Connection Profiles

A single physical printer may have multiple connection profiles.

Example:

- IPP for printing
- SMB for scan delivery
- SNMP for status
- Local Agent for fallback
- Cloud Relay for remote access

The UI must treat these as one logical printer.

### FR-CON-009 — Connection Priority

The system must allow connection priority to be set automatically or manually.

Example:

1. Direct IPP
2. Local Agent
3. OS Printer
4. Cloud Relay

### FR-CON-010 — Automatic Fallback

When a connection fails, PrinterHub should:

1. determine whether another approved connection is available
2. attempt the fallback when safe
3. preserve the user's job options where possible
4. notify the user of the connection switch
5. avoid duplicate print jobs

Automatic fallback should be configurable.

### FR-CON-011 — Manual Connection Switching

The user must be able to manually switch connection methods for a printer.

### FR-CON-012 — Connection Health

Each connection should show:

- connected
- degraded
- unavailable
- authentication required
- configuration required

The system should record latency and recent failure state where useful.

### FR-CON-013 — Browser-Native Direct LAN Connection

Where the printer and browser security model permit it, PrinterHub should be able to communicate directly with a printer from the PWA over HTTPS without requiring the Local Agent.

Potential direct-browser services include:

- IPP/IPPS over HTTP(S)
- eSCL/AirScan over HTTP(S)
- documented manufacturer HTTP APIs
- printer Embedded Web Server endpoints intended for programmatic access

Before enabling this mode, PrinterHub must validate:

- printer reachability
- TLS/certificate compatibility
- browser mixed-content restrictions
- CORS behavior
- supported protocol endpoints

If direct browser communication is blocked or unsupported, PrinterHub must offer the Local Agent or another configured connection instead.

### FR-CON-014 — QR Code Pairing

Users should be able to pair a printer by scanning a QR code with the device camera.

A pairing QR may contain non-secret metadata such as:

- printer identifier
- IP address or hostname
- model
- IPP/IPPS endpoint
- eSCL endpoint
- organization or location identifier
- optional PrinterHub pairing token with short expiry

The QR must not contain long-lived passwords or reusable administrator credentials.

PrinterHub should use the browser camera with BarcodeDetector where supported and a compatible JavaScript/WebAssembly decoder as fallback.

### FR-CON-015 — BLE / iBeacon Proximity Discovery

Where compatible BLE hardware is available, PrinterHub Mobile may identify nearby printers or PrinterHub gateways using native Bluetooth APIs. The Web/PWA may use Web Bluetooth only where the browser supports the required behavior.

BLE discovery is intended for proximity identification and pairing assistance, not as a guaranteed full print transport.

For the Xerox VersaLink C7130 specifically, Xerox documents Bluetooth as iBeacon functionality with the optional wireless kit. PrinterHub must therefore use it as a discovery/proximity signal unless further device-specific protocol testing proves otherwise.

### FR-CON-016 — Direct Cable Modes

Direct cable support is capability-gated.

- Android may use native USB host/OTG APIs when a compatible printer protocol path exists.
- Browser WebUSB may be offered experimentally on supported Chromium-class environments.
- iOS/iPadOS generic USB printer/scanner control is not assumed.

If direct cable mode is unavailable or insufficient, PrinterHub must fall back to local network, Wi-Fi Direct, native print framework, another printer, or an optional future gateway.

### FR-CON-017 — NFC Tap-to-Pair

Where a printer or attached tag exposes compatible NFC metadata and the browser supports Web NFC, PrinterHub may offer tap-to-pair.

NFC should primarily bootstrap printer identity or connection metadata. It should not store permanent credentials.

A QR code must remain available as the more broadly compatible visual pairing alternative.

---

## 9. Printer Onboarding

### FR-ONB-001 — Add Printer

The Add Printer screen must provide:

- Find printers automatically
- Enter IP address
- Use installed system printer
- Connect through Local Agent
- USB printer
- Wi-Fi Direct
- Remote printer / Cloud Relay

### FR-ONB-002 — Capability Detection

After a printer is added, PrinterHub should detect or ask the user to confirm:

- print support
- scan support
- copy support
- color support
- duplex support
- paper sizes
- available trays
- document feeder
- flatbed
- finishing options
- supported resolutions
- supported document formats
- consumable reporting
- status reporting

### FR-ONB-003 — Printer Naming

The user may set a friendly name such as:

- Office Xerox
- Front Desk Printer
- Home Printer

The original manufacturer/model must remain available in device details.

### FR-ONB-004 — Location

Users may assign a non-sensitive organizational location such as:

- Main Office
- Reception
- Upstairs
- Store Room
- Branch A

### FR-ONB-005 — Test Connection

The system must provide a test function for each configured connection.

### FR-ONB-006 — Test Print

The user should be able to send a simple test page.

### FR-ONB-007 — Test Scan Destination

For scan-to-folder workflows, the system should verify that the configured destination is reachable and writable.

---

## 10. Printer Dashboard

Each printer should have a unified dashboard.

The dashboard should show:

- friendly name
- manufacturer and model
- online/offline status
- current connection
- backup connection availability
- printer IP where applicable
- active jobs
- recent jobs
- toner/ink levels when available
- paper tray status when available
- paper size
- warnings
- errors
- scanner availability
- Local Agent status
- last communication time

Primary actions:

- Print
- Scan
- Copy
- Scan to Email
- Scan to Drive
- Scan to Folder
- Job Queue
- Printer Settings

---

## 11. Printing Requirements

### FR-PRN-001 — File Upload Printing

Users must be able to upload common printable formats.

At minimum:

- PDF
- JPEG
- PNG

Where preprocessing support exists:

- TIFF

Where conversion support exists:

- DOCX
- XLSX
- PPTX
- TXT

### FR-PRN-002 — Drag and Drop

Desktop users should be able to drag files onto the print area.

### FR-PRN-003 — Mobile File Selection

Mobile users should be able to choose files from:

- Files
- Downloads
- Photos
- supported cloud storage providers

### FR-PRN-004 — Print Preview

PrinterHub should render a preview before submission where technically possible.

### FR-PRN-005 — Copies

Users must be able to select the number of copies.

### FR-PRN-006 — Color Mode

Supported options:

- Auto
- Color
- Black and white / grayscale

### FR-PRN-007 — Duplex

Supported options where available:

- Single-sided
- Double-sided long-edge
- Double-sided short-edge

### FR-PRN-008 — Page Range

Users must be able to print:

- all pages
- selected pages
- page ranges

### FR-PRN-009 — Page Size

Support common paper sizes such as:

- A4
- A3
- Letter
- Legal
- custom sizes where printer permits

### FR-PRN-010 — Orientation

- Auto
- Portrait
- Landscape

### FR-PRN-011 — Scaling

- Actual size
- Fit to page
- Shrink oversized pages
- Custom scale

### FR-PRN-012 — Tray Selection

Users should be able to select:

- Auto
- Tray 1
- Tray 2
- other detected trays
- bypass/manual feed

### FR-PRN-013 — Media Type

Where supported:

- Plain
- Heavy
- Labels
- Envelope
- Glossy
- Custom media profiles

### FR-PRN-014 — Collation

Users should be able to enable/disable collated copies where supported.

### FR-PRN-015 — Finishing

Where the printer supports it:

- stapling
- hole punching
- booklet
- folding
- output tray selection

### FR-PRN-016 — Secure Print

Where supported, users should be able to submit a PIN-protected print job.

### FR-PRN-017 — Print Presets

Users must be able to save presets such as:

- A4 Black & White
- A4 Color Duplex
- Draft
- Photo
- Office Document
- ID Card Copy

### FR-PRN-018 — Print from URL

Authorized users may provide a supported URL for PrinterHub to retrieve and print, subject to security validation.

### FR-PRN-019 — Print Queue

The user must see:

- queued
- processing
- printing
- completed
- cancelled
- failed

### FR-PRN-020 — Cancel Job

Users should be able to cancel jobs that have not completed, where the connection method supports it.

### FR-PRN-021 — Retry Job

Failed jobs should be retryable without re-uploading the file where retention policy permits.

### FR-PRN-022 — Duplicate Protection

The system must avoid accidental duplicate jobs during retries or connection fallback.

### FR-PRN-023 — Document Preflight

Before printing, PrinterHub should inspect the document where possible and report:

- page count
- detected page dimensions
- mixed page sizes
- orientation
- oversized pages
- unsupported media sizes
- file conversion requirements

The app should warn the user before submission when selected print settings are likely to crop or rescale content.

### FR-PRN-024 — Print Quality

Where supported, users should be able to choose printer-supported quality modes such as:

- Draft / Toner Saver
- Standard
- High Quality
- device-supported DPI or resolution modes

Only capabilities reported by the selected printer/driver should be shown.

### FR-PRN-025 — Browser Native Print Fallback

When direct IPP, Local Agent, or another preferred transport cannot be used, PrinterHub may provide a browser-native print fallback.

The application should:

1. prepare a print-friendly representation of the document
2. open the operating-system/browser print dialog
3. clearly state that PrinterHub cannot fully control printer-specific settings in this fallback mode

This fallback should never be represented as equivalent to managed IPP job submission.

### FR-PRN-026 — Direct Browser IPP

Where CORS, TLS, browser networking rules, and the printer permit it, PrinterHub may construct and submit IPP jobs directly from the browser.

The direct IPP implementation should support:

- capability query before submission
- binary IPP request encoding
- job submission
- job identifier capture
- status polling where available
- progress/status presentation

If browser policy blocks the request, PrinterHub must automatically offer another configured connection.

### FR-PRN-027 — Secure Print Credential Handling

Secure-print PINs or release codes must:

- remain in memory only unless the user explicitly chooses an approved secure credential mechanism
- never appear in logs
- never be included in QR/NFC pairing metadata
- follow the target printer's supported PIN length and encryption requirements

### FR-PRN-028 — Native Mobile Print Sheet

PrinterHub Mobile should expose a native print-sheet fallback.

On iOS/iPadOS this should use the system AirPrint experience. On Android this should use the Android printing framework / compatible print service.

The app should prepare the document correctly before handing it to the OS and should explain that some vendor-specific options may be controlled by the native print service rather than PrinterHub.

### FR-PRN-029 — Print from Share Extension / Intent

When a user shares a printable document to PrinterHub, the app should open directly into:

1. printer selection
2. preview
3. print options
4. submit

### FR-PRN-030 — Mobile Local Print Privacy

For direct local print jobs, PrinterHub should support a mode in which the document is processed and sent from the mobile device directly to the printer without storing the document bytes in the cloud.

The backend may receive metadata such as job ID, printer ID, settings, timestamps, and final state when the user/organization policy allows it.

---

## 12. Scanning Requirements

### FR-SCN-001 — Scan Inbox

PrinterHub must provide a Scan Inbox where incoming scans appear.

Each item should display:

- file name
- thumbnail where possible
- page count
- file type
- size
- source printer
- scan timestamp

### FR-SCN-002 — Scan Acquisition Methods

Scanning may be implemented using one or more of:

- eSCL / AirScan
- SMB scan destination
- SFTP/FTP destination where appropriate
- email ingestion
- TWAIN
- WIA
- SANE
- vendor API
- Local Agent
- watched folder
- cloud connector

### FR-SCN-003 — Start Scan from App

Where the printer/driver/protocol permits remote scan initiation, users should be able to start a scan from PrinterHub.

If the device requires physical confirmation, PrinterHub should clearly instruct the user.

### FR-SCN-004 — Scanner Source

Where supported:

- automatic document feeder
- flatbed
- auto source

### FR-SCN-005 — Scan Sides

- single-sided
- double-sided

### FR-SCN-006 — Scan Color

- Color
- Grayscale
- Black and white
- Auto

### FR-SCN-007 — Resolution

Common options should include:

- 150 DPI
- 200 DPI
- 300 DPI
- 400 DPI
- 600 DPI

Only supported values should be shown when known.

### FR-SCN-008 — Output Format

At minimum:

- PDF
- JPEG
- PNG
- TIFF where supported

### FR-SCN-009 — Multi-Page PDF

Multiple scanned pages should be combinable into one PDF.

### FR-SCN-010 — Searchable PDF

Users should be able to apply OCR and create searchable PDFs.

### FR-SCN-011 — OCR

OCR should:

- extract text
- support searchable PDF
- optionally save plain text
- preserve original scan
- indicate OCR processing status

### FR-SCN-012 — Scan Preview

Users should be able to preview scanned pages before finalizing where the workflow permits.

### FR-SCN-013 — Page Editing

Users should be able to:

- rotate pages
- reorder pages
- remove pages
- crop pages
- deskew where available
- combine scans
- split documents

### FR-SCN-014 — Scan Naming

Users should be able to:

- manually name scans
- use automatic names
- configure naming templates

Example:

`Invoice_2026-09-19_001.pdf`

### FR-SCN-015 — Scan to Folder

Users should be able to route a scan to a configured folder.

### FR-SCN-016 — Scan to Email

Users should be able to send scanned documents by email through an approved email integration.

### FR-SCN-017 — Scan to Cloud Storage

Support should be extendable to:

- Google Drive
- OneDrive
- Dropbox
- S3-compatible storage

### FR-SCN-018 — Scan and Download

The user must be able to download a completed scan to their current device.

### FR-SCN-019 — Scan to Print

Users should be able to scan a document and immediately print it.

### FR-SCN-020 — Scan Routing Rules

Advanced users may configure rules such as:

- scans from Printer A → Folder A
- scans named "Invoice" → accounting folder
- scans from Reception → email specific mailbox

### FR-SCN-021 — eSCL / AirScan Pull Scanning

Where the printer reports compatible eSCL/AirScan support, PrinterHub should be able to perform pull scanning.

The adapter should be able to:

- query scanner capabilities
- query scanner status
- construct scan-job requests
- select platen/flatbed or ADF where supported
- select simplex/duplex
- select color mode
- select supported resolution
- select output format
- retrieve scan output
- handle multi-page ADF jobs

This feature must be capability-detected rather than assumed for every printer.

### FR-SCN-022 — Scanner Readiness Check

Before remote scan initiation, PrinterHub should check available scanner state information and present conditions such as:

- scanner ready
- scanner busy
- ADF loaded
- ADF empty
- paper jam
- cover/platen condition where exposed
- authentication required
- unsupported source

The application should not submit a scan job known to be impossible until the blocking condition is resolved.

### FR-SCN-023 — Streamed Scan Retrieval and Progress

For protocols that deliver scan data as a stream, PrinterHub should process the stream incrementally instead of waiting for the entire document in memory.

The UI should show:

- receiving state
- pages received where known
- bytes received where known
- progress percentage when the protocol supplies enough information
- processing/finalizing state

Large scan processing should be moved to Web Workers or background workers where practical to keep the UI responsive.

### FR-SCN-024 — ID Card 2-in-1 Mode

PrinterHub should provide an ID-card workflow.

Typical flow:

1. scan the front side
2. prompt the user to flip the card
3. scan the back side
4. automatically align and place both sides on one A4/Letter page
5. allow preview before save or print

The feature should support both PDF output and direct copy/print where available.

### FR-SCN-025 — Image Adjustment Tools

The scan editor should support, where practical:

- brightness
- contrast
- grayscale conversion
- threshold adjustment for black-and-white documents
- automatic deskew
- manual crop
- automatic edge detection
- orientation correction

Adjustments should preserve the original scan unless the user explicitly replaces it.

### FR-SCN-026 — Private Client-Side OCR

PrinterHub should offer an optional local OCR mode that runs in the browser or Local Agent, such as through a WebAssembly OCR engine.

When local OCR mode is selected:

- document content must not be sent to an external OCR service
- the original scan must be preserved
- searchable/selectable text may be embedded into a derived PDF
- OCR progress and failure state must be visible

Cloud OCR may exist as a separate opt-in feature.

### FR-SCN-027 — Native Share and Multi-Target Export

On mobile, users should be able to send a scan through the native operating-system share sheet. On the Web/PWA, PrinterHub may use the Web Share API where supported.

Potential destinations may include installed applications such as:

- messaging apps
- AirDrop or nearby-share mechanisms
- Slack or collaboration tools
- mail apps
- local file destinations

PrinterHub should also allow one scan to be dispatched to multiple approved destinations in one workflow, such as local save + Drive + print.

### FR-SCN-028 — Mobile Camera Scan Fallback

The mobile app should allow the phone camera to create a clean document scan when the printer scanner is unavailable.

The result must be clearly labeled as a mobile-camera scan rather than a scan produced by the printer.

### FR-SCN-029 — Mobile Scan-to-App

For compatible printers, PrinterHub Mobile should receive scan data directly into the app without requiring the user to configure a desktop folder.

Preferred methods include direct eSCL/AirScan-compatible retrieval or another supported mobile scanner protocol.

### FR-SCN-030 — Mobile Scan Progress and Recovery

If the app temporarily loses foreground execution or network connectivity during a scan, it should recover the job state where the printer/protocol permits, avoid creating duplicate jobs, and present a clear retry path.

---

## 13. Copy Requirements

### FR-CPY-001 — Copy Workflow

Where supported, PrinterHub should provide a copy workflow.

### FR-CPY-002 — Copy Settings

Options should include where available:

- copies
- color/B&W
- duplex source
- duplex output
- paper size
- tray
- scaling
- collation

### FR-CPY-003 — Scan-to-Print Fallback

If native remote copy control is unavailable, PrinterHub may implement copy as:

1. scan
2. receive document
3. submit print job

The UI should tell the user if the operation is implemented this way.

---

## 14. Document Management

### FR-DOC-001 — Recent Documents

Users should be able to access recent uploaded and scanned documents.

### FR-DOC-002 — Search

Users should be able to search by:

- file name
- OCR text
- printer
- date
- document type
- tag

### FR-DOC-003 — Tags

Users may assign tags to documents.

### FR-DOC-004 — Rename

Users may rename documents.

### FR-DOC-005 — Delete

Users may delete documents subject to organization retention policies.

### FR-DOC-006 — Reprint

Users should be able to reprint a previous job.

### FR-DOC-007 — Rescan

Users should be able to repeat the settings from a previous scan.

### FR-DOC-008 — Retention Controls

Administrators should be able to configure how long uploaded and scanned documents are retained.

Possible policies:

- delete immediately after job completion
- 1 day
- 7 days
- 30 days
- custom
- retain until manually deleted

---

## 15. Job Management

### FR-JOB-001 — Unified Job History

PrinterHub should maintain a history of:

- print jobs
- scan jobs
- copy jobs
- document routing jobs

### FR-JOB-002 — Job Details

Each job should show:

- job ID
- user
- printer
- connection used
- backup connection if fallback occurred
- document
- settings
- status
- submitted time
- completed time
- error reason

### FR-JOB-003 — Live Updates

Job statuses should update without requiring a full page refresh.

### FR-JOB-004 — Filters

Users should be able to filter by:

- printer
- user
- job type
- date
- status

### FR-JOB-005 — Administrative Job Control

Authorized administrators may:

- cancel jobs
- reorder queued jobs where supported
- pause queue
- resume queue

---

## 16. Device Status and Monitoring

### FR-MON-001 — Online Status

The system should show whether a printer is:

- online
- offline
- sleeping
- unknown
- unreachable

### FR-MON-002 — Consumables

Where supported, show:

- black toner/ink
- cyan
- magenta
- yellow
- drum / imaging units
- waste toner
- fuser where exposed
- maintenance kit

### FR-MON-003 — Paper Status

Where supported:

- tray
- paper size
- remaining/empty state
- media type
- paper orientation where exposed
- tray open/closed state where exposed

### FR-MON-004 — Device Alerts

Display alerts such as:

- out of paper
- low toner
- paper jam
- door open
- scanner unavailable
- service required
- tray mismatch
- authentication failure
- network unreachable

### FR-MON-005 — Status Refresh

Status should refresh automatically at a reasonable interval without overloading devices.

### FR-MON-006 — Device Uptime / Reachability History

Administrators may view recent online/offline history.

### FR-MON-007 — Notifications

Users may opt into notifications for:

- print complete
- print failed
- scan received
- printer offline
- toner low
- paper empty
- agent disconnected

### FR-MON-008 — Capability-Gated Maintenance Actions

For printers that expose documented and authorized maintenance controls, administrators may be able to initiate actions such as:

- print configuration/report page
- color registration or calibration
- refresh device status
- warm reboot/restart

Maintenance actions must:

- be hidden when unsupported
- require appropriate administrator permission
- show the exact action before execution
- request explicit confirmation for disruptive actions such as reboot
- write an audit-log entry
- never rely on undocumented destructive commands

---

## 17. Presets and Automation

### FR-AUT-001 — Saved Print Presets

Users may save commonly used print configurations.

### FR-AUT-002 — Saved Scan Presets

Example presets:

- Scan to PDF
- Searchable PDF
- Receipt
- ID Document
- High Quality
- Email Scan
- Scan to Drive

### FR-AUT-003 — Default Actions

A user may configure defaults per printer.

### FR-AUT-004 — Quick Actions

The dashboard may expose one-tap actions such as:

- Scan to My Email
- Scan to Drive
- Print Last Document
- B&W Duplex Print

### FR-AUT-005 — Workflow Templates

Organizations may create reusable workflows such as:

**Invoice Intake**
- Scan from ADF
- OCR
- Searchable PDF
- Name using date
- Save to accounting folder
- Email copy to finance

---

## 18. User Accounts and Authentication

### FR-AUTH-001 — Guest / Local Mode

For local-only deployments, administrators may enable a limited guest mode.

### FR-AUTH-002 — User Accounts

The cloud-enabled product should support account creation and login.

### FR-AUTH-003 — Authentication Methods

Potential methods:

- email/password
- magic link
- passkey
- Google
- Microsoft

### FR-AUTH-004 — Sessions

Users should be able to see and revoke active sessions.

### FR-AUTH-005 — Multi-Factor Authentication

MFA should be available for organization administrators.

---

## 19. Roles and Permissions

Supported roles may include:

### Owner
Full organization access.

### Administrator
Manage printers, users, connections, policies, and jobs.

### Operator
Print, scan, copy, and manage assigned queues.

### User
Use allowed printers and view own jobs.

### Viewer
Read-only monitoring.

Permissions should support:

- printer access
- scan destination access
- color printing permission
- maximum copies
- remote printing permission
- job cancellation
- document history access
- printer administration

---

## 20. Organizations and Multi-Printer Support

### FR-ORG-001 — Organizations

Users may belong to one or more organizations/workspaces.

### FR-ORG-002 — Multiple Printers

Organizations may register multiple printers.

### FR-ORG-003 — Printer Groups

Examples:

- Lagos Office
- Abuja Office
- Reception
- Finance
- Color Printers

### FR-ORG-004 — Default Printer

Users may define a default printer.

### FR-ORG-005 — Shared Printers

Administrators may share specific printers with selected users or groups.

---

## 21. Remote Access

### FR-REM-001 — Secure Outbound Tunnel

Remote access should use an outbound authenticated connection from the Local Agent/gateway.

### FR-REM-002 — Remote Printing

Authorized users may submit print jobs remotely.

### FR-REM-003 — Remote Status

Users may see printer status while away from the local network.

### FR-REM-004 — Remote Scan Retrieval

Scans delivered locally should be optionally synchronized to the user's account.

### FR-REM-005 — Remote Operation Controls

Administrators must be able to disable remote printing or remote scan access per printer.

---

## 22. Optional Gateway / Desktop Agent Requirements

### FR-AGT-001 — Optional Installation

The Gateway/Desktop Agent is optional and should have a straightforward installer or container deployment when an organization chooses to use it. It is not required for standard mobile users.

### FR-AGT-002 — Background Operation

The agent should run in the background after installation.

### FR-AGT-003 — Browser Detection

PrinterHub should automatically detect a local agent where technically possible.

### FR-AGT-004 — Secure Pairing

The web account and Local Agent must use a secure pairing workflow.

### FR-AGT-005 — Device Discovery

The agent should detect:

- USB printers
- OS printers
- CUPS printers
- supported network printers
- scanner interfaces

### FR-AGT-006 — Local API

The agent may expose a tightly scoped authenticated local API to the PrinterHub web client.

### FR-AGT-007 — Auto Update

The agent should support signed updates.

### FR-AGT-008 — Agent Diagnostics

The user should be able to view:

- version
- operating system
- detected printers
- service health
- recent errors
- connection state

### FR-AGT-009 — Agent Restart

Where permitted, the user should be able to restart the agent service.

### FR-AGT-010 — Secure Loopback Bridge

The Local Agent may expose a loopback HTTP/WebSocket interface for the PWA to access capabilities unavailable to normal browser networking.

Examples include:

- SNMP queries
- raw print transport where required
- OS printer enumeration
- TWAIN/WIA/SANE scan acquisition
- USB device access
- watched scan folders

The bridge must bind only to approved local interfaces by default, authenticate requests, validate browser origin, and reject unauthenticated commands.

---

## 23. Network Scanner Folder / SMB Requirements

### FR-SMB-001 — Managed Scan Folder

PrinterHub should support a dedicated scan folder monitored by the Local Agent or local server.

### FR-SMB-002 — Device Credentials

Printer-specific scan credentials must be stored securely.

### FR-SMB-003 — Incoming File Detection

New scans should appear in the Scan Inbox automatically.

### FR-SMB-004 — Duplicate Detection

Repeated file delivery should not create duplicate scan records.

### FR-SMB-005 — File Completion Detection

PrinterHub must ensure the printer has finished writing a file before processing it.

---

## 24. Notifications

Users should be able to configure:

- in-app notifications
- browser push notifications
- email notifications

Potential notification events:

- scan received
- print completed
- print failed
- printer offline
- printer back online
- toner low
- toner critical
- paper empty
- Local Agent offline
- remote gateway disconnected

---

## 25. Error Handling

### FR-ERR-001 — Human-Readable Errors

PrinterHub must translate protocol-level errors into actionable messages.

Instead of:

`IPP client-error-not-possible`

show:

`The printer rejected this job. Check the selected paper size or tray.`

### FR-ERR-002 — Suggested Recovery

Errors should offer relevant actions such as:

- Retry
- Try backup connection
- Select another tray
- Reconnect Local Agent
- Re-enter credentials
- Open printer web interface
- Use another printer

### FR-ERR-003 — Connection Diagnostics

A diagnostics screen should test:

- device reachability
- IPP
- status channel
- scan destination
- Local Agent
- authentication
- cloud relay

### FR-ERR-004 — Diagnostic Export

Users should be able to export a sanitized diagnostic report that excludes passwords and secrets.

---

## 26. Security Requirements

### FR-SEC-001 — Encrypted Communication

Cloud communications must use HTTPS/TLS.

### FR-SEC-002 — IPPS Preference

Where supported, secure IPP should be preferred.

### FR-SEC-003 — Credential Storage

Passwords, SMB credentials, tokens, and API keys must be encrypted at rest.

### FR-SEC-004 — No Secret Logging

Passwords, tokens, API keys, document contents, and sensitive credentials must not appear in logs.

### FR-SEC-005 — Local Network Safety

PrinterHub should not require users to expose printer ports to the public internet.

### FR-SEC-006 — Permission Checks

Every remote or organization operation must be authorization-checked.

### FR-SEC-007 — Audit Log

Administrative actions should be recorded.

### FR-SEC-008 — Document Privacy

Users and administrators must be able to control document retention.

### FR-SEC-009 — Automatic Cleanup

Temporary print conversion files should be deleted after they are no longer required.

### FR-SEC-010 — Agent Trust

Only paired and authorized web sessions should be allowed to issue commands to the Local Agent.

### FR-SEC-011 — Private Local Processing Mode

PrinterHub should provide a privacy-first mode in which document processing stays on the user's device or local network.

In this mode:

- documents are not uploaded to PrinterHub cloud storage
- PDF manipulation occurs in-browser or in the Local Agent
- OCR uses local/client-side processing
- temporary files follow local cleanup policy
- cloud-only destinations are disabled unless the user explicitly opts in

### FR-SEC-012 — Browser Direct-Connection Safety

Before direct browser communication with a printer, PrinterHub must validate the transport environment.

The application should detect and explain:

- HTTPS page attempting insecure HTTP printer access
- certificate trust failures
- CORS rejection
- unavailable local-network permission where the browser/OS enforces one
- blocked ports or endpoints

PrinterHub must not instruct users to disable browser-wide security protections as the default fix.

### FR-SEC-013 — Pairing Metadata Safety

QR, NFC, and BLE pairing payloads must contain only the minimum data required to locate or identify the printer.

Long-lived passwords, administrator credentials, cloud API keys, and reusable access tokens must not be stored in visible pairing payloads.

Short-lived pairing tokens must expire and be single-use where feasible.

---

## 27. Audit Logs

Authorized administrators should be able to view events such as:

- user logged in
- printer added
- printer removed
- connection modified
- credentials changed
- print submitted
- scan received
- job cancelled
- remote access enabled
- remote access disabled
- user permissions changed

Audit records should include:

- actor
- action
- target
- timestamp
- outcome

---

## 28. Offline and Local-Only Operation

### FR-OFF-001 — Local Tasks Without Internet

Local printing and scanning should remain available when internet access is unavailable, where architecture permits.

### FR-OFF-002 — PWA Cache

The PWA should cache essential application resources.

### FR-OFF-003 — Reconnection

When internet connectivity returns, non-sensitive metadata may synchronize automatically.

### FR-OFF-004 — Local-Only Deployment

Advanced users or organizations should eventually be able to deploy PrinterHub without cloud dependency.

### FR-OFF-005 — Local Printer Profile Cache

Successfully paired printer profiles should be cached locally so the PWA can quickly show known devices after restart.

Suitable local storage may include IndexedDB.

The cache may include:

- printer identifier
- friendly name
- non-secret endpoints
- detected capabilities
- user preferences
- last known reachability state

Secrets must not be stored in plaintext browser storage.

### FR-OFF-006 — Startup Reachability Refresh

On startup, PrinterHub should asynchronously test saved local printer profiles and update their availability badges without blocking the rest of the UI.

---

## 29. Integrations

The architecture should permit integrations with:

- Google Drive
- OneDrive
- Dropbox
- Gmail / email delivery
- S3-compatible storage
- SMB network shares
- SFTP
- webhooks
- third-party workflow automation platforms

Integrations should be optional and permission-controlled.

---

## 30. Printer Web Interface Access

Where a printer exposes an embedded web interface, PrinterHub may provide an "Open Printer Admin" action.

PrinterHub must not attempt to bypass device authentication.

---

## 31. Multi-Vendor Architecture

PrinterHub must avoid hard-coding the entire application around the Xerox VersaLink C7130.

A printer adapter/provider layer should normalize device capabilities.

Example logical providers:

- Generic IPP
- CUPS
- Windows Print
- macOS Print
- Xerox
- HP
- Canon
- Brother
- Epson
- Ricoh
- Kyocera
- Konica Minolta

A normalized printer capability model should describe:

- printing
- scanning
- copying
- duplex
- color
- supported media
- trays
- status
- consumables
- finishing

---

## 32. APIs

PrinterHub should expose internal APIs for:

- printers
- connections
- jobs
- scans
- documents
- presets
- users
- organizations
- Local Agent communication
- notifications

A future developer API may allow external apps to:

- submit print jobs
- retrieve status
- receive scan events
- receive printer alerts

API access must use scoped authentication.

---

## 33. Search

Global search should help users find:

- printers
- print jobs
- scans
- documents
- users
- presets

---

## 34. Accessibility

The UI should support:

- keyboard navigation
- screen readers
- sufficient contrast
- visible focus states
- descriptive labels
- responsive typography
- touch-friendly controls

The application should target WCAG 2.1 AA where practical.

---

## 35. Responsive Design

PrinterHub should be designed for:

- desktop monitors
- laptops
- tablets
- mobile phones

Important actions such as Print and Scan must remain easy to access on small screens.

---

## 36. PWA Requirements

Where supported, users should be able to:

- install PrinterHub from the browser
- launch it from the home screen/app launcher
- receive push notifications
- use cached application UI
- open shared files into PrinterHub
- share scanned documents out through the operating-system share sheet
- use the camera for QR printer pairing
- register PrinterHub as a share target for supported document types

PWA features must degrade gracefully when a browser does not implement a required web capability.

---

## 37. File Handling

PrinterHub should:

- validate uploaded file type
- enforce configurable size limits
- scan uploaded files for unsafe content where appropriate
- isolate file processing
- generate thumbnails asynchronously
- avoid executing uploaded documents
- remove temporary files according to retention policy

---

## 38. Conversion Service

For formats that printers do not accept directly, PrinterHub may convert documents to a standard printable format such as PDF.

The user should be notified if conversion could alter layout.

---

## 39. OCR and Document Intelligence

Optional advanced functionality may include:

- OCR
- automatic orientation correction
- blank-page removal
- document type detection
- invoice/receipt extraction
- barcode/QR detection
- automatic file naming
- searchable archives

These features should preserve the original scan.

---

## 40. Usage Analytics

Organizations may optionally view:

- jobs per printer
- pages printed
- color vs black-and-white usage
- scan volume
- failed jobs
- busiest printers
- busiest periods

Analytics should respect document privacy and not require storing document contents.

---

## 41. Cost and Quota Controls

Organizations may configure:

- maximum copies per job
- color printing restrictions
- page quotas
- printer access by group
- remote printing restrictions

Future versions may estimate printing cost based on configurable page rates.

---

## 42. Administration

The administration area should allow:

- printer management
- user management
- group management
- roles
- connection settings
- fallback settings
- scan destinations
- document retention
- notifications
- audit logs
- organization settings
- Local Agent management

---

## 43. Backup and Restore

For self-hosted deployments, administrators should be able to back up:

- configuration
- printer profiles
- users
- presets
- metadata

Secrets should be handled separately and securely.

---

## 44. Localization

The product should be built so UI text can be translated.

Initial language:

- English

Future languages may be added without redesigning application logic.

---

## 45. Theme

The interface should support:

- light mode
- dark mode
- system theme

The initial visual direction may prioritize a clean dark interface with clear printer-state indicators.

---

## 46. Logging

Logs should support troubleshooting while excluding:

- passwords
- tokens
- document content
- full authentication headers
- sensitive scan contents

Log levels:

- error
- warning
- info
- debug

Debug mode should be explicitly enabled.

---

## 47. Reliability Requirements

The system should:

- avoid submitting duplicate print jobs
- survive Local Agent restarts
- reconnect to printers after temporary network loss
- retry transient failures with bounded retry logic
- persist job state
- detect stale agent sessions
- prevent endless retry loops

---

## 48. Performance Requirements

Target behavior:

- dashboard initial load: under 3 seconds on a normal broadband/LAN connection
- printer status refresh: typically within 5–15 seconds depending on protocol
- local print submission acknowledgement: typically within 3 seconds after document processing
- new scan detection: ideally within 5 seconds after the file is fully delivered
- streamed scan/document processing should support files of at least 50 MB without freezing the main UI thread on supported hardware
- CPU-heavy PDF, image, QR, and OCR processing should use Web Workers/background workers where practical
- streamed transfers should avoid unnecessary full-file memory copies

Large documents may require longer processing.

---

## 49. Browser Limitations

PrinterHub must explicitly account for browser security limitations.

A standard browser cannot be assumed to have unrestricted direct access to:

- USB printers
- TWAIN
- WIA
- SANE
- CUPS sockets
- SMB
- SNMP
- arbitrary LAN ports

Features requiring these capabilities should be routed through:

- PrinterHub Gateway/Desktop Agent
- trusted local gateway
- server-side service where appropriate

Browser-native WebUSB, Web Bluetooth, Web NFC, camera QR scanning, direct IPP, and direct eSCL may be offered when the current browser and device support them, but they must be treated as capability-gated transports rather than universal assumptions.

The UI should never pretend a feature is available when the required browser feature, protocol, permission, hardware capability, or bridge is not installed or connected.

---

## 50. Data Model — High-Level

### User

- id
- name
- email
- role
- preferences

### Organization

- id
- name
- settings

### Printer

- id
- organization_id
- friendly_name
- manufacturer
- model
- serial identifier where available
- location
- capabilities
- status
- default_connection_id

### Connection

- id
- printer_id
- type
- priority
- configuration
- status
- last_success
- last_failure

### PrintJob

- id
- user_id
- printer_id
- document_id
- settings
- connection_used
- status
- timestamps

### ScanJob

- id
- user_id
- printer_id
- settings
- output_document_id
- status
- timestamps

### Document

- id
- owner_id
- file_name
- mime_type
- size
- page_count
- storage_reference
- retention_expiry

### Preset

- id
- user_or_org
- type
- settings

### LocalAgent

- id
- organization_id
- device_name
- OS
- version
- status
- last_seen

---

## 51. Core User Flows

### 50.1 Add a Network Printer

1. User opens Add Printer.
2. Selects "Find printers on network."
3. PrinterHub/Local Agent discovers devices.
4. User selects a printer.
5. PrinterHub detects connection methods.
6. PrinterHub tests capabilities.
7. User confirms printer name.
8. Printer appears on dashboard.

### 50.2 Add by IP

1. User selects "Enter IP address."
2. Enters IP/hostname.
3. PrinterHub tests supported protocols.
4. Available features are displayed.
5. User saves the printer.

### 50.3 Print a PDF

1. User selects printer.
2. Clicks Print.
3. Uploads PDF.
4. Chooses options.
5. Reviews preview.
6. Clicks Print.
7. PrinterHub chooses the preferred connection.
8. Job status appears.
9. User receives completion/failure state.

### 50.4 Automatic Print Fallback

1. User submits job.
2. Preferred IPP connection is unavailable.
3. PrinterHub checks backup methods.
4. Local Agent is available.
5. PrinterHub routes the job through Local Agent.
6. User sees "Printed using backup connection."
7. Only one physical job is produced.

### 50.5 Scan to PrinterHub

1. User places paper in ADF.
2. User chooses PrinterHub scan destination on the printer or starts scan in the app where supported.
3. Printer sends file to managed destination.
4. PrinterHub detects completed file.
5. Scan appears in Scan Inbox.
6. User previews or edits it.
7. User downloads, prints, emails, or sends it to cloud storage.

### 50.6 Scan and Print

1. User chooses Scan → Print.
2. Selects scan settings.
3. Scans document.
4. PrinterHub receives the scan.
5. User optionally previews.
6. PrinterHub submits a print job.

### 50.7 Remote Print

1. User opens PrinterHub away from the office.
2. Selects an online remote printer.
3. Uploads document.
4. PrinterHub encrypts and queues the job.
5. Local Agent receives the job through secure outbound relay.
6. Local Agent prints it.
7. Status synchronizes back to the user.

---

## 52. Recommended Navigation

### Main Navigation

- Home
- Printers
- Print
- Scan
- Documents
- Jobs
- Presets
- Notifications
- Settings

### Organization/Admin Navigation

- Users
- Groups
- Printers
- Local Agents
- Connections
- Policies
- Integrations
- Audit Log
- Organization Settings

---

## 53. Suggested Home Dashboard

The home dashboard should prioritize actions over technical details.

Example:

```text
PrinterHub

My Printers

Xerox VersaLink C7130
Online
Primary: IPP
Backup: Local Agent

[ Print ] [ Scan ] [ Copy ]

Recent
Invoice.pdf       Printed
Contract.pdf      Scanned
Report.pdf        Failed

Quick Actions
[ Scan to Email ]
[ B&W Duplex ]
[ Scan to Drive ]
```

---

## 54. Suggested Connection UI

```text
Add Printer

Recommended
[ Find printers automatically ]

Other connection methods
[ Enter IP Address ]
[ Installed Printer ]
[ USB / Local Agent ]
[ Wi-Fi Direct ]
[ Remote Printer ]

Need help?
Run connection diagnostics
```

Printer details:

```text
Office Xerox

Primary Connection
IPP
Connected

Backup Connections
Local Agent       Available
OS Printer        Available
Cloud Relay       Available

Status Channel
SNMP              Connected

Scan Channel
SMB               Connected

[ Test All Connections ]
[ Change Priority ]
```

---

## 55. MVP Requirements

The first production milestone is **Backend Core + PrinterHub Mobile**, with the Web/PWA following on the same backend.

### 55.1 Backend MVP

The backend must include:

1. Authentication and sessions.
2. User and organization model.
3. Roles and permissions.
4. Mobile device registration.
5. Printer profiles.
6. Connection-profile metadata.
7. Normalized printer capability schema.
8. Job model for print, scan, and copy.
9. Idempotency / duplicate-job protection.
10. Presets.
11. Document metadata.
12. Optional encrypted object storage.
13. Local-execution job reporting.
14. WebSocket/SSE or equivalent live status.
15. APNs/FCM notification infrastructure.
16. Audit logs.
17. API versioning and OpenAPI contract.
18. Feature flags.
19. Vendor/model capability registry.
20. Test printer simulator / mocked protocol responses for client development.

### 55.2 Mobile MVP

The first mobile release should include:

1. iOS/iPadOS and Android clients.
2. Login and organization selection.
3. Automatic local printer discovery.
4. Add printer by IP/hostname.
5. Xerox C7130 capability profile and live probing.
6. QR pairing.
7. NFC-assisted pairing where supported.
8. BLE/iBeacon nearby-printer indication where supported.
9. Native AirPrint flow on Apple platforms.
10. Android Print Framework / compatible print-service flow.
11. Direct IPP/IPPS path where validated.
12. Wi-Fi Direct workflow where the printer has the optional wireless kit.
13. PDF/JPEG/PNG/TIFF print intake as supported.
14. Copies, color, duplex, page range, size, orientation, scaling, and tray selection where available.
15. Print preview.
16. Direct printer scan via eSCL/AirScan-compatible path if verified on target firmware.
17. Scanner source, simplex/duplex, color mode, resolution, and output format.
18. Multi-page scan.
19. Scan preview and page editing.
20. Scan → Print.
21. ID Card 2-in-1 workflow.
22. Local OCR option.
23. Phone-camera document scan.
24. Native share-in and share-out.
25. Printer online/offline state.
26. Consumable/status information where reachable.
27. Automatic connection fallback.
28. Manual connection switching under Advanced settings.
29. Offline local printer profiles.
30. Synchronized print/scan history.
31. Human-readable diagnostics.
32. Local-execution privacy mode with no mandatory cloud document upload.

### 55.3 Web MVP — After Mobile Core

The Web/PWA should then consume the same backend and provide:

1. Authentication and organization access.
2. Printer inventory.
3. Documents.
4. Job history.
5. Presets.
6. Administration.
7. Monitoring.
8. Browser-native print dialog.
9. Direct browser IPP/eSCL where security policy permits.
10. QR/manual-IP printer setup where browser capabilities permit.
11. Responsive desktop/mobile UI.

---

## 56. Version 2

Potential Version 2 functionality:

- Google Drive, OneDrive, Dropbox, and S3 integrations
- scan to email
- secure print / PIN workflows
- richer Xerox finishing controls
- searchable PDF and enhanced OCR
- consumable alerts
- advanced workflow presets
- organization quotas and accounting
- usage analytics
- remote cloud documents
- remote job approval/release
- printer sharing by team/location
- multi-printer routing
- Android USB OTG support for validated devices
- deeper NFC pairing
- deeper vendor-specific status adapters
- optional always-on PrinterHub Gateway
- browser push notifications
- PWA sharing targets
- capability-gated maintenance actions

---

## 57. Version 3 / Advanced

Potential advanced functionality:

- multi-location enterprise fleet management
- vendor-specific adapter marketplace/SDK
- enterprise SSO
- SCIM/user provisioning
- API keys and public developer API
- webhooks
- high availability
- managed PrinterHub Gateway appliance
- remote browser jobs executed by an authorized local mobile/gateway device
- print-cost accounting
- rules-based printer selection
- automatic document classification
- invoice/receipt extraction
- barcode/QR document workflows
- AI-assisted printer troubleshooting
- predictive consumable alerts
- fleet health reporting

---

## 58. Technical Direction

Recommended architecture:

### Backend

- FastAPI
- PostgreSQL
- Redis where required
- OpenAPI-first API contracts
- WebSocket or SSE for live job/status updates
- APNs and FCM for mobile push notifications
- S3-compatible object storage for optional cloud documents
- background worker queue for document conversion/OCR/integrations
- explicit idempotency keys for job creation
- feature flags and model capability registry

The backend should be independently deployable in Docker and should not contain assumptions that require the printer to be on the same network as the backend.

### Mobile

Recommended direction:

- React Native + TypeScript to align with the web TypeScript ecosystem
- native Swift modules where iOS APIs require them
- native Kotlin modules where Android APIs require them
- avoid depending on a browser WebView for core printer networking
- use a custom native build when Wi-Fi Direct, NFC, BLE, local networking, or USB APIs require native modules

Potential mobile modules:

- local-network discovery
- Bonjour/mDNS
- Android DNS-SD / Wi-Fi P2P
- native printing
- IPP/IPPS client
- eSCL/AirScan client
- NFC
- BLE/iBeacon
- QR scanner
- camera document scanner
- secure Keychain/Keystore storage
- background transfer/task manager
- native share extensions/intents

### Web

- Next.js
- TypeScript
- Tailwind CSS
- shadcn/ui
- PWA support
- Service Worker
- IndexedDB for non-secret local cache
- Web Workers for document processing
- Web Share API where supported
- BarcodeDetector / QR decoder
- capability-gated direct IPP/eSCL
- browser-native print fallback

### Shared Packages

Where practical, mobile and web should share:

- TypeScript API client
- OpenAPI-generated types
- validation schemas
- printer capability types
- job models
- preset schemas
- document metadata types
- business rules that do not depend on platform hardware APIs

### Printing

- iOS/iPadOS AirPrint native flow
- Android Print Framework / compatible print service
- direct IPP/IPPS
- browser native print dialog
- optional gateway/CUPS later
- vendor adapters where needed

### Scanning

- direct eSCL/AirScan-compatible scanning where verified
- mobile-native/vendor-supported scanner path
- network scan destinations where useful
- phone-camera scan fallback
- optional gateway SMB/SFTP/TWAIN/WIA/SANE later

### Document and Media Processing

- PDF preview and composition
- image rasterization
- page rotation/reordering/cropping
- perspective correction
- ID-card 2-in-1 composition
- local OCR
- mobile/background processing
- Web Workers on web

### Monitoring

- IPP printer attributes
- HTTP/HTTPS device status
- SNMP only where the client/gateway platform safely supports it
- vendor interfaces where appropriate

### Storage

Support two modes:

**Local-first:** document stays on the phone/browser and only metadata synchronizes.

**Cloud document:** document is intentionally uploaded to encrypted object storage for cross-device access, integrations, remote workflows, or retention.

Organization policy may control which mode is allowed.

---

## 59. Product Principle

The defining principles for PrinterHub are:

> **One backend, multiple clients, multiple ways to reach the printer.**

> **On mobile, the phone is the local printer bridge.**

The user should not need to understand IPP, SMB, SNMP, TWAIN, WIA, SANE, CUPS, or printer drivers.

PrinterHub should determine what is available, expose the capabilities in simple language, select the best connection, and provide a safe fallback when the preferred connection is unavailable.

---

## 60. Acceptance Criteria for Initial Xerox VersaLink C7130 Prototype

The initial C7130 mobile prototype is successful when:

- PrinterHub Mobile can discover the C7130 automatically on the same LAN where the network advertises compatible services.
- The C7130 can also be added manually by IP address.
- PrinterHub creates one logical printer profile and records every verified usable connection method.
- The app correctly identifies the device as Xerox VersaLink C7130/C7100 Series.
- A PDF can be printed successfully from iPhone/iPad using an appropriate AirPrint/native route.
- A PDF can be printed successfully from Android using an appropriate Android/native or direct IPP route.
- Direct IPP/IPPS is tested and used when reliable.
- Print options such as copies, color/B&W, duplex, size, orientation, and page range work to the extent supported by the chosen connection.
- PrinterHub can initiate and retrieve a real printer scan through a verified mobile-compatible scanning path.
- If eSCL/AirScan is not exposed by the tested C7130 firmware/configuration, PrinterHub detects that fact and uses another supported scan path rather than assuming support.
- Multi-page ADF scanning is validated.
- Scan preview, page editing, save, share, and Scan → Print work.
- NFC/QR pairing is tested.
- Wi-Fi Direct is tested if the target printer has the optional wireless kit installed.
- BLE/iBeacon is treated as discovery/proximity only unless protocol testing proves a richer capability.
- Printer online/offline state is visible.
- At least two print connection paths can be configured when the hardware/network exposes them.
- The app can fail over between safe connection paths without producing duplicate print jobs.
- Local print operation can work when PrinterHub cloud is temporarily unavailable.
- Backend state synchronizes after connectivity returns.
- No desktop agent or on-premises Docker service is required for the normal mobile flow.

---

## 61. Success Metrics

Useful product metrics include:

- printer setup completion rate
- average time to add a printer
- successful print job rate
- successful scan ingestion rate
- percentage of failed primary connections recovered by fallback
- duplicate print rate
- average job submission time
- mobile printer discovery success rate
- percentage of users who connect without manually entering an IP address
- native/direct connection fallback success rate
- number of printers managed per organization
- number of support incidents requiring manual protocol configuration

The most important qualitative measure is whether a user can print or scan successfully without needing to understand printer networking protocols.


---

## 62. Research-Validated Target Device Profile — Xerox VersaLink C7130

The reference machine shown for this project is a **Xerox VersaLink C7130**, part of the VersaLink C7100 Series.

The product must treat the following as the validated baseline for this target family.

### 62.1 Standard Device Functions

Xerox documents the C7130 as a color multifunction device with:

- print
- copy
- scan
- email
- cloud functions
- automatic two-sided printing

The C7130 is rated up to 30 ppm for A4/Letter and supports print image quality up to 1200 × 2400.

### 62.2 Physical / Network Connectivity

Xerox documents:

**Standard**
- 10/100/1000 Base-T Ethernet
- high-speed USB 3.0
- NFC Tap-to-Pair

**Optional wireless kit**
- Wi-Fi
- Wi-Fi Direct
- Bluetooth iBeacon

Therefore PrinterHub must **detect** wireless capability and must not assume every C7130 includes the optional wireless kit.

### 62.3 Mobile Printing

Xerox lists support for:

- Apple AirPrint
- Mopria Print Service
- Xerox Print Service for Android
- @PrintByXerox
- optional Xerox Workplace Mobile App

PrinterHub should prioritize standards-based and OS-native paths before requiring vendor-specific software.

### 62.4 Mobile Scanning

Xerox lists mobile scanning support through:

- Mopria Scan
- Apple AirPrint/mobile scanning support as documented by Xerox
- optional Xerox Workplace Mobile App

PrinterHub should still probe the exact scan protocol exposed by the target firmware before enabling direct eSCL/AirScan controls.

### 62.5 Scan Features

Xerox documents scan destinations including:

- Email
- Home
- Network / FTP
- SMB
- USB
- SFTP in current product literature

Supported scan output includes combinations of:

- JPG
- PDF
- PDF/A
- single-page PDF
- multi-page PDF
- password-protected PDF
- searchable PDF
- TIFF

The platform also documents OCR and TWAIN support.

### 62.6 Document Feeder

The C7100 Series uses a single-pass duplex automatic document feeder (DADF) with a 130-sheet capacity and published scanning performance up to 80 images per minute in the relevant configuration.

PrinterHub should expose ADF/duplex scan controls only after capability probing.

### 62.7 Print Features Relevant to PrinterHub

Useful documented capabilities include:

- two-sided printing
- scaling
- draft mode
- secure print
- personal print
- sample set
- saved jobs
- booklet layout
- N-up
- paper selection
- job monitoring
- finishing options depending on installed hardware

PrinterHub must avoid displaying finishing options that are not physically installed.

### 62.8 Device Management / Security

Xerox documents:

- Embedded Web Server
- SNMPv3
- TLS 1.3 / SSL support
- IPsec
- certificate management
- role-based permissions
- secure print
- audit logging
- IP/port filtering

PrinterHub should prefer authenticated/encrypted transports when configured and should not ask users to weaken device security just to make the app work.

---

## 63. Platform Capability Matrix

| Capability | Android App | iPhone/iPad App | Web/PWA | Optional Gateway |
|---|---|---|---|---|
| Same-LAN printer discovery | Strong | Strong | Limited/browser-dependent | Strong |
| Manual IP/hostname | Yes | Yes | Yes, subject to browser networking | Yes |
| Native OS printing | Android Print Framework | AirPrint | Browser print dialog | OS/CUPS |
| Direct IPP/IPPS | Yes | Yes, if implemented/validated | Sometimes; CORS/TLS dependent | Yes |
| Direct eSCL/AirScan | Yes, if printer exposes it | Yes, if printer exposes it | Sometimes; CORS/TLS dependent | Yes |
| Wi-Fi Direct | Strong native support on Android; device-dependent | Usually guided join + local protocol use | User-managed network join | Yes |
| NFC pairing | Strong | Capability-limited but usable for supported NDEF/deep-link flows | Generally not dependable | Hardware-dependent |
| BLE/iBeacon discovery | Yes | Yes | Browser-dependent | Hardware-dependent |
| QR pairing | Yes | Yes | Yes with camera permission | Optional |
| USB printer/scanner | Possible via Android USB host for validated devices | Do not assume generic support | Experimental WebUSB on some browsers | Strongest option |
| SNMP | Native networking possible, policy-dependent | Native networking possible, policy-dependent | Generally unsuitable directly | Yes |
| SMB/SFTP local workflows | Possible with native implementation | Possible with native implementation but not primary UX | Browser unsuitable | Yes |
| Camera document scan | Yes | Yes | Basic camera capture possible | No |
| Offline local print/scan | Yes | Yes | Partial | Yes |
| No extra office installation required | Yes | Yes | Yes, but fewer capabilities | No |

This table represents intended product capability, not a promise that every printer exposes every protocol.

---

## 64. Backend-First Engineering Contract

The backend must be sufficiently complete that both mobile and web clients can be developed without inventing separate business rules.

### 64.1 Required API Domains

- `/auth`
- `/users`
- `/organizations`
- `/memberships`
- `/devices`
- `/printers`
- `/printer-connections`
- `/printer-capabilities`
- `/jobs`
- `/print-jobs`
- `/scan-jobs`
- `/copy-jobs`
- `/documents`
- `/presets`
- `/workflows`
- `/notifications`
- `/integrations`
- `/audit`
- `/analytics`
- `/feature-flags`

Exact routes may differ, but the domain boundaries should remain clear.

### 64.2 Client Capability Declaration

Each client should tell the backend what it can execute.

Example capability set:

```json
{
  "platform": "ios",
  "clientVersion": "1.0.0",
  "capabilities": {
    "nativePrint": true,
    "directIpp": true,
    "directEscl": true,
    "wifiDirect": false,
    "nfc": true,
    "ble": true,
    "usbHost": false,
    "cameraScan": true
  }
}
```

The backend may use this for feature flags and UX coordination, but final printer capability must still be determined locally.

### 64.3 Local Job Execution State

For a local mobile print job:

```text
Created
→ Preparing
→ Connecting
→ Submitted to printer
→ Processing
→ Completed / Failed / Unknown
```

The mobile app is authoritative for local transport events and synchronizes state to the backend.

### 64.4 Idempotency

Every job submission must have an idempotency identifier so:

- reconnects do not duplicate jobs
- retries are safe
- fallback does not accidentally print twice

### 64.5 Privacy Modes

Backend APIs must support:

**Metadata-only local job**
- document stays on device
- backend receives job metadata/state only

**Cloud document job**
- document intentionally uploads
- backend stores and serves it according to retention policy

### 64.6 Printer Capability Snapshots

The app should upload a sanitized capability snapshot after successful probing so the same printer profile can be recognized across the user's devices.

Live local probing remains authoritative because installed options and firmware settings can change.

---

## 65. Revised Delivery Roadmap

### Phase 0 — Hardware and Protocol Validation

Using the Xerox VersaLink C7130:

- inventory installed options
- confirm whether optional wireless kit is present
- confirm Ethernet/IP addressing
- confirm NFC behavior
- test AirPrint
- test Android print path
- test IPP/IPPS
- test advertised Bonjour/DNS-SD services
- probe eSCL/AirScan endpoints
- test Wi-Fi Direct if installed
- inspect EWS/status endpoints
- validate safe status/telemetry paths
- document actual firmware-specific behavior

### Phase 1 — Backend Foundation

Complete:

- authentication
- organizations
- printer model
- capability model
- connection model
- jobs
- documents
- presets
- audit logs
- notifications
- feature flags
- OpenAPI contract
- realtime events
- test fixtures / simulated printer responses

### Phase 2 — PrinterHub Mobile

Build the first production client:

- discovery
- pairing
- C7130 profile
- printing
- scanning
- fallback
- local privacy mode
- document editing
- sharing
- offline local operation
- backend synchronization

### Phase 3 — Web/PWA

Reuse the backend for:

- organization dashboard
- printer inventory
- history
- documents
- presets
- administration
- browser-supported printing/scanning
- PWA installation

### Phase 4 — Multi-Vendor Expansion

Add and validate adapters/profiles for:

- HP
- Canon
- Brother
- Epson
- Ricoh
- Kyocera
- Konica Minolta
- other standards-compatible MFPs

### Phase 5 — Optional Enterprise Gateway

Only if customer workflows require it:

- always-on local execution
- browser-only office workflows
- centralized USB/TWAIN/WIA/SANE/CUPS
- remote print/scan
- deeper fleet telemetry

---

## 66. Research Sources Used for Version 2.0

The mobile-first update was informed by current manufacturer/platform documentation, including:

1. Xerox VersaLink C7120/C7125/C7130 Detailed Specifications  
   https://www.office.xerox.com/latest/VC7SS-02.pdf

2. Xerox VersaLink C7100 Series Evaluator Guide  
   https://www.office.xerox.com/latest/VC7EG-01D.pdf

3. Xerox VersaLink C7100 Product Brochure  
   https://www.office.xerox.com/latest/VC7BR-05U.PDF

4. Xerox VersaLink C71XX User Guide  
   https://download.support.xerox.com/pub/docs/VLC70XX/userdocs/any-os/en_GB/VersaLink_C71XX_mfp_ug_en-US.pdf

5. Xerox VersaLink Series System Administrator Guide  
   https://download.support.xerox.com/pub/docs/VLB71XX/userdocs/any-os/en_GB/VersaLink_series_sag_en-US.pdf

6. Apple — About AirPrint  
   https://support.apple.com/en-gb/102895

7. Apple Developer — Local Network Privacy  
   https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription

8. Android Developers — WifiP2pManager  
   https://developer.android.com/reference/android/net/wifi/p2p/WifiP2pManager.html

9. Mopria — Scan to Android  
   https://mopria.org/scan-to-android

These sources validate the C7130's standard Ethernet/USB/NFC connectivity, optional Wi-Fi/Wi-Fi Direct/iBeacon capabilities, AirPrint/Mopria support, scan destinations/formats, mobile scan support, DADF, and relevant platform networking behaviors. Protocol endpoints such as eSCL must still be verified against the actual device firmware/configuration during Phase 0.
