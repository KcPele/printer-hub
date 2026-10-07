"""Flags the clients are built against. Changing a default here does not
overwrite a value an operator has already set."""

# key: (enabled by default, description)
BUILT_IN_FLAGS: dict[str, tuple[bool, str]] = {
    # Mobile MVP capabilities (FRD §55.2). On by default; turn one off to
    # disable a transport that misbehaves in the field.
    "direct_ipp": (True, "Print by sending IPP/IPPS directly from the app."),
    "escl_scan": (True, "Scan directly from the printer with eSCL/AirScan."),
    "wifi_direct": (True, "Offer the Wi-Fi Direct connection workflow."),
    "nfc_pairing": (True, "Offer NFC tap-to-pair where the device supports it."),
    "ble_proximity": (True, "Show nearby printers detected through BLE/iBeacon."),
    "camera_scan": (True, "Phone-camera document capture."),
    "local_ocr": (True, "On-device OCR."),
    "cloud_documents": (True, "Upload documents to cloud storage, where policy allows."),
    # Version 2 features (FRD §56). Off until built.
    "scan_to_email": (False, "Send scans by email."),
    "cloud_storage_integrations": (False, "Google Drive, OneDrive, Dropbox, and S3 destinations."),
    "secure_print": (False, "PIN-protected print jobs."),
    "usage_analytics": (False, "Usage analytics for organization administrators."),
    "android_usb_otg": (False, "Direct USB printing on Android for validated devices."),
    "remote_printing": (False, "Print to a printer outside the local network."),
}
