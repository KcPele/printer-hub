"""Built-in capability profiles: the catalogue of printer families.

The Xerox VersaLink C7100 profile is written from Xerox's own specification. The others are
baselines for a whole family, whose models differ, so anything that varies within the family
is listed in `optional_features` and confirmed by probing. A profile never overrides what a
device reports about itself.
"""

from app.modules.capabilities.schemas import (
    CapabilityProfileWrite,
    Connectivity,
    CopyCapabilities,
    DuplexMode,
    PrintCapabilities,
    PrinterCapabilities,
    ProfileCategory,
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
    category=ProfileCategory.OFFICE_MULTIFUNCTION,
    summary="A3 colour multifunction for a busy office: prints, copies, and scans.",
    popularity=100,
    model_patterns=["*VersaLink C71*", "*C7120*", "*C7125*", "*C7130*"],
    setup_tips=[
        "Connect the printer to the office network by cable. AirPrint and Mopria printing are "
        "switched on as it comes.",
        "To scan from the app, switch on Mopria scanning in the printer's web page, under "
        "Connectivity. That switches on AirPrint scanning too.",
        "Wi-Fi, Wi-Fi Direct, and Bluetooth need the optional wireless kit. Without it, tap the "
        "phone on the NFC mark or add the printer by its address.",
        "If the app asks who is printing, an administrator has switched on IPP authentication. "
        "Ask them for the user name and password.",
    ],
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

_A4_AND_LETTER = ["iso_a4_210x297mm", "na_letter_8.5x11in", "na_legal_8.5x14in"]
_A3_AND_LEDGER = ["iso_a3_297x420mm", "na_ledger_11x17in", *_A4_AND_LETTER]
_PHOTO_SIZES = [*_A4_AND_LETTER[:2], "iso_a5_148x210mm", "na_index-4x6_4x6in"]
_ALL_SIDES = [
    DuplexMode.ONE_SIDED,
    DuplexMode.TWO_SIDED_LONG_EDGE,
    DuplexMode.TWO_SIDED_SHORT_EDGE,
]
_RASTER = ["image/urf", "image/pwg-raster", "image/jpeg"]

_SAME_NETWORK = (
    "Put the printer on the same Wi-Fi or office network as your phone. It then appears under "
    "Nearby printers."
)
_BY_ADDRESS = (
    "If it does not appear, print a network configuration page from the printer's panel to "
    "find its IP address, and add it by address."
)
_WAKE_IT = (
    "Wake the printer before you look for it. Many home printers stop answering on Wi-Fi "
    "while they sleep."
)
_MOBILE_PRINTING_ON = (
    "AirPrint or Mopria must be switched on in the printer's network settings. It is on as "
    "the printer comes."
)
_SCAN_ON = (
    "If the app finds the printer but not its scanner, switch on AirPrint or Mopria scanning "
    "in the printer's web page."
)
_ASK_ADMIN = (
    "If the app asks who is printing, an administrator has set a user name and password for "
    "printing. Ask them for it."
)


def _family(
    manufacturer: str,
    display_name: str,
    patterns: list[str],
    *,
    category: ProfileCategory,
    summary: str,
    popularity: int,
    color: bool,
    a3: bool = False,
    notes: list[str] | None = None,
) -> CapabilityProfileWrite:
    """The baseline for a family, from the kind of machine it is.

    An office machine is a laser on a wired network that reads PDF and prints both sides. A
    home machine is an inkjet on Wi-Fi that may do neither, so it is sent pictures of pages.
    """
    office = category in (ProfileCategory.OFFICE_MULTIFUNCTION, ProfileCategory.OFFICE_PRINTER)
    scans = category in (
        ProfileCategory.OFFICE_MULTIFUNCTION,
        ProfileCategory.HOME_MULTIFUNCTION,
    )
    sizes = _A3_AND_LEDGER if a3 else _A4_AND_LETTER if office else _PHOTO_SIZES
    optional = ["connectivity.wifi_direct", "connectivity.nfc"]
    if not office:
        # Two-sided printing and PDF are on some home models and not others.
        optional += ["print.duplex_modes", "print.document_formats"]
    if scans:
        optional += ["protocols.escl", "scan.sources", "scan.adf_duplex"]
    if office:
        # A laser family has mono and colour models, wired and wireless.
        optional += ["print.color", "connectivity.wifi", "print.finishing"]

    tips = [_SAME_NETWORK]
    if not office:
        tips.append(_WAKE_IT)
    tips += [_BY_ADDRESS, _MOBILE_PRINTING_ON]
    if scans:
        tips.append(_SCAN_ON)
    if office:
        tips.append(_ASK_ADMIN)

    return CapabilityProfileWrite(
        manufacturer=manufacturer,
        display_name=display_name,
        category=category,
        summary=summary,
        popularity=popularity,
        model_patterns=patterns,
        capabilities=PrinterCapabilities(
            print=PrintCapabilities(
                supported=True,
                color=color,
                duplex_modes=_ALL_SIDES if office else [DuplexMode.ONE_SIDED],
                media_sizes=sizes,
                quality_modes=["draft", "normal", "high"],
                document_formats=["application/pdf", *_RASTER] if office else _RASTER,
                collation=office,
            ),
            scan=ScanCapabilities(
                supported=scans,
                sources=[ScanSource.PLATEN, ScanSource.ADF]
                if scans and office
                else [ScanSource.PLATEN]
                if scans
                else [],
                color_modes=[ScanColorMode.COLOR, ScanColorMode.GRAYSCALE] if scans else [],
                resolutions_dpi=[150, 300, 600] if scans else [],
                document_formats=["application/pdf", "image/jpeg"] if scans else [],
                max_width_mm=(297 if a3 else 216) if scans else None,
                max_height_mm=(432 if a3 else 297) if scans else None,
            ),
            copy_=CopyCapabilities(supported=scans),
            status=StatusCapabilities(reporting=True, consumables=True, trays=office),
            connectivity=Connectivity(
                ethernet=True if office else None,
                wifi=None if office else True,
                usb=True,
            ),
            protocols=Protocols(
                ipp=True,
                ipps=True if office else None,
                airprint=True,
                mopria=True,
                escl=None,
                snmp=True if office else None,
                http_ews=True,
            ),
        ),
        optional_features=optional,
        notes=[
            "This is the baseline for a family whose models differ. Probe the device and "
            "believe what it reports.",
            *(notes or []),
        ],
        setup_tips=tips,
    )


_OFFICE_MFP = ProfileCategory.OFFICE_MULTIFUNCTION
_OFFICE_PRINTER = ProfileCategory.OFFICE_PRINTER
_HOME_MFP = ProfileCategory.HOME_MULTIFUNCTION
_HOME_PRINTER = ProfileCategory.HOME_PRINTER

_HP_HOST = (
    "HP LaserJet MFP M630 and Color LaserJet FlowMFP M578 refuse a scan unless the "
    "request's Host is localhost."
)
_BROTHER_FEEDER = (
    "Brother feeders lose pages when asked for the next one at once: pause between pages."
)
_RICOH_STATUS = "Some Ricoh scanners leave a scan pending until asked for ScannerStatus."
_XEROX_B = "Xerox B205 and B215 answer 404 or 410 while a scanned page is still on its way."
_CANON_IR = "Canon iR2625/2630 advertise 600 dpi scanning and deliver 300."
_KYOCERA_TLS = "Kyocera ECOSYS M6526cdn cuts its TLS answer to a scan request short."

BUILT_IN_PROFILES = [
    XEROX_VERSALINK_C7100,
    # --- Home ----------------------------------------------------------------
    _family(
        "HP",
        "DeskJet, ENVY, and Smart Tank",
        ["*DeskJet*", "*ENVY*", "*Smart Tank*", "*Ink Tank*"],
        category=_HOME_MFP,
        popularity=95,
        color=True,
        summary="Wi-Fi inkjets for the home that print, copy, and scan.",
    ),
    _family(
        "Epson",
        "EcoTank",
        ["*ET-[0-9]*", "*L[0-9][0-9][0-9][0-9]*"],
        category=_HOME_MFP,
        popularity=92,
        color=True,
        summary="Refillable ink-tank printers, most with a scanner on top.",
    ),
    _family(
        "Canon",
        "PIXMA",
        ["*PIXMA*", "*TS[0-9]*", "*TR[0-9]*", "*MG[0-9]*", "*G[0-9][0-9][0-9][0-9]*"],
        category=_HOME_MFP,
        popularity=90,
        color=True,
        summary="Wi-Fi inkjets for documents and photos at home.",
    ),
    _family(
        "Epson",
        "Expression and WorkForce",
        ["*XP-[0-9]*", "*WF-[0-9]*"],
        category=_HOME_MFP,
        popularity=84,
        color=True,
        summary="Inkjets for the home and the small office, many with a feeder.",
    ),
    _family(
        "HP",
        "OfficeJet",
        ["*OfficeJet*"],
        category=_HOME_MFP,
        popularity=83,
        color=True,
        summary="Inkjet multifunctions for a home office, with a feeder for scanning.",
    ),
    _family(
        "Brother",
        "MFC-J and DCP-J inkjets",
        ["*MFC-J*", "*DCP-J*", "*MFC-T*", "*DCP-T*"],
        category=_HOME_MFP,
        popularity=78,
        color=True,
        summary="Inkjet multifunctions for the home and the small office.",
        notes=[_BROTHER_FEEDER],
    ),
    _family(
        "Canon",
        "MAXIFY",
        ["*MAXIFY*", "*GX[0-9]*", "*MB[0-9][0-9][0-9][0-9]*"],
        category=_HOME_MFP,
        popularity=70,
        color=True,
        summary="Inkjets built for a small office's daily printing.",
    ),
    _family(
        "Canon",
        "SELPHY",
        ["*SELPHY*"],
        category=_HOME_PRINTER,
        popularity=55,
        color=True,
        summary="Pocket-sized photo printers.",
    ),
    # --- Office --------------------------------------------------------------
    _family(
        "HP",
        "LaserJet Pro MFP",
        ["*LaserJet*MFP*", "*Laser MFP*"],
        category=_OFFICE_MFP,
        popularity=88,
        color=False,
        summary="Laser multifunctions for a small office or a team.",
        notes=[_HP_HOST],
    ),
    _family(
        "HP",
        "LaserJet",
        ["*LaserJet*", "*Laser [0-9]*"],
        category=_OFFICE_PRINTER,
        popularity=86,
        color=False,
        summary="Laser printers, from the desk to the department.",
    ),
    _family(
        "Brother",
        "MFC-L and DCP-L lasers",
        ["*MFC-L*", "*DCP-L*"],
        category=_OFFICE_MFP,
        popularity=85,
        color=False,
        summary="Compact laser multifunctions for a small office.",
        notes=[_BROTHER_FEEDER],
    ),
    _family(
        "Brother",
        "HL-L lasers",
        ["*HL-L*"],
        category=_OFFICE_PRINTER,
        popularity=80,
        color=False,
        summary="Compact laser printers for the desk.",
    ),
    _family(
        "Canon",
        "i-SENSYS and imageCLASS MF",
        ["*MF[0-9]*"],
        category=_OFFICE_MFP,
        popularity=76,
        color=False,
        summary="Laser multifunctions for a small office.",
    ),
    _family(
        "Canon",
        "imageRUNNER",
        ["*imageRUNNER*", "*iR-ADV*", "*iR[0-9]*", "*iR C[0-9]*"],
        category=_OFFICE_MFP,
        popularity=72,
        color=True,
        a3=True,
        summary="A3 multifunctions for a department.",
        notes=[_CANON_IR],
    ),
    _family(
        "Xerox",
        "VersaLink",
        ["*VersaLink*"],
        category=_OFFICE_MFP,
        popularity=74,
        color=True,
        summary="Office printers and multifunctions with a touch screen.",
    ),
    _family(
        "Xerox",
        "AltaLink and WorkCentre",
        ["*AltaLink*", "*WorkCentre*"],
        category=_OFFICE_MFP,
        popularity=68,
        color=True,
        a3=True,
        summary="A3 multifunctions for a large office.",
        notes=[_XEROX_B],
    ),
    _family(
        "Xerox",
        "B and C series",
        ["*B2[0-9]5*", "*B3[0-9]5*", "*C2[0-9]5*", "*C3[0-9]5*"],
        category=_OFFICE_MFP,
        popularity=64,
        color=False,
        summary="Compact lasers for a small office.",
        notes=[_XEROX_B],
    ),
    _family(
        "Kyocera",
        "ECOSYS",
        ["*ECOSYS*"],
        category=_OFFICE_MFP,
        popularity=66,
        color=False,
        summary="Long-life lasers for a small office or a team.",
        notes=[_KYOCERA_TLS],
    ),
    _family(
        "Kyocera",
        "TASKalfa",
        ["*TASKalfa*"],
        category=_OFFICE_MFP,
        popularity=60,
        color=True,
        a3=True,
        summary="A3 multifunctions for a department.",
    ),
    _family(
        "Ricoh",
        "IM and MP",
        ["*IM [0-9C]*", "*MP [0-9C]*"],
        category=_OFFICE_MFP,
        popularity=65,
        color=True,
        a3=True,
        summary="A3 multifunctions for a department.",
        notes=[_RICOH_STATUS],
    ),
    _family(
        "Ricoh",
        "SP and M series",
        ["*SP [0-9C]*", "M [0-9C]*", "* M [0-9C]*"],
        category=_OFFICE_MFP,
        popularity=52,
        color=False,
        summary="Compact lasers for a small office.",
        notes=[_RICOH_STATUS],
    ),
    _family(
        "Lexmark",
        "MB, MC, MX, and CX",
        [
            "*MB[0-9][0-9][0-9][0-9]*",
            "*MC[0-9][0-9][0-9][0-9]*",
            "*MX[0-9][0-9][0-9]*",
            "*CX[0-9][0-9][0-9]*",
        ],
        category=_OFFICE_MFP,
        popularity=58,
        color=False,
        summary="Laser multifunctions for a small office or a team.",
    ),
    _family(
        "Lexmark",
        "B, C, MS, and CS",
        ["*B[0-9][0-9][0-9][0-9]*", "*C[0-9][0-9][0-9][0-9]*", "*MS[0-9][0-9]*", "*CS[0-9][0-9]*"],
        category=_OFFICE_PRINTER,
        popularity=50,
        color=False,
        summary="Laser printers for the desk and the team.",
    ),
    _family(
        "Samsung",
        "Xpress and ProXpress",
        ["*Xpress*", "*M[0-9][0-9][0-9][0-9]*", "*C[0-9][0-9][0-9]*"],
        category=_OFFICE_MFP,
        popularity=48,
        color=False,
        summary="Compact lasers, now looked after by HP.",
    ),
    _family(
        "Konica Minolta",
        "bizhub",
        ["*bizhub*"],
        category=_OFFICE_MFP,
        popularity=56,
        color=True,
        a3=True,
        summary="A3 multifunctions for a department.",
    ),
    _family(
        "Sharp",
        "MX and BP",
        ["*MX-*", "*BP-*"],
        category=_OFFICE_MFP,
        popularity=46,
        color=True,
        a3=True,
        summary="A3 multifunctions for a department.",
    ),
]
