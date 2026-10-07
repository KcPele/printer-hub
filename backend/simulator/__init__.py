"""A fake Xerox VersaLink C7130 for client development (FRD §55.1 item 20).

Speaks enough IPP and eSCL for a client to probe capabilities, print, scan,
and exercise its fallback and error handling without the hardware. It shares
no code with `app/`: the backend never talks to a printer.
"""
