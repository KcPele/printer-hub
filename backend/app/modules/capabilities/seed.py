"""Built-in capability profiles."""

from app.modules.capabilities.schemas import (
    CapabilityProfileWrite,
    Connectivity,
    CopyCapabilities,
    DuplexMode,
    PrintCapabilities,
    PrinterCapabilities,
    Protocols,
    ScanCapabilities,
    ScanColorMode,
    ScanSource,
    StatusCapabilities,
)

# Baseline from Xerox's published specifications, as summarized in FRD §62.
XEROX_VERSALINK_C7100 = CapabilityProfileWrite(
    manufacturer="Xerox",
    display_name="VersaLink C7100 Series",
    model_patterns=["*VersaLink C71*", "*C7120*", "*C7125*", "*C7130*"],
    capabilities=PrinterCapabilities(
        print=PrintCapabilities(
            supported=True,
            color=True,
            duplex_modes=[
                DuplexMode.ONE_SIDED,
                DuplexMode.TWO_SIDED_LONG_EDGE,
                DuplexMode.TWO_SIDED_SHORT_EDGE,
            ],
            media_sizes=[
                "iso_a3_297x420mm",
                "iso_a4_210x297mm",
                "iso_a5_148x210mm",
                "na_letter_8.5x11in",
                "na_legal_8.5x14in",
                "na_ledger_11x17in",
            ],
            media_types=["stationery", "stationery-heavyweight", "labels", "envelope"],
            resolutions_dpi=[600, 1200],
            quality_modes=["draft", "normal", "high"],
            document_formats=["application/pdf", "image/jpeg", "image/urf", "image/pwg-raster"],
            max_copies=999,
            collation=True,
            secure_print=True,
        ),
        scan=ScanCapabilities(
            supported=True,
            sources=[ScanSource.PLATEN, ScanSource.ADF],
            adf_duplex=True,
            color_modes=[
                ScanColorMode.COLOR,
                ScanColorMode.GRAYSCALE,
                ScanColorMode.BLACK_AND_WHITE,
            ],
            resolutions_dpi=[150, 200, 300, 400, 600],
            document_formats=["application/pdf", "image/jpeg"],
            max_width_mm=297,
            max_height_mm=432,
        ),
        copy_=CopyCapabilities(supported=True, native_remote_control=False),
        status=StatusCapabilities(reporting=True, consumables=True, trays=True),
        connectivity=Connectivity(
            ethernet=True,
            usb=True,
            nfc=True,
            wifi=None,
            wifi_direct=None,
            ble_beacon=None,
        ),
        protocols=Protocols(
            ipp=True,
            ipps=True,
            airprint=True,
            mopria=True,
            escl=None,
            snmp=True,
            http_ews=True,
            smb_scan=True,
        ),
    ),
    optional_features=[
        "connectivity.wifi",
        "connectivity.wifi_direct",
        "connectivity.ble_beacon",
        "protocols.escl",
    ],
    notes=[
        "Wi-Fi, Wi-Fi Direct, and Bluetooth iBeacon need the optional wireless kit. "
        "Detect them; do not assume them.",
        "Bluetooth is iBeacon only: use it for proximity and discovery, not for print data.",
        "Xerox lists Mopria Scan and AirPrint scanning. Probe eSCL on the installed "
        "firmware before enabling direct scan controls.",
        "NFC Tap-to-Pair carries identification metadata, not documents.",
    ],
)

BUILT_IN_PROFILES = [XEROX_VERSALINK_C7100]
