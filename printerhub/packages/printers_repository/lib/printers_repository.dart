/// The printers of a workspace, and what the devices themselves report.
library;

export 'package:api_client/api_client.dart'
    show
        ConnectionRead,
        ConnectionType,
        PrinterCapabilitiesOutput,
        PrinterRead,
        PrinterStatus;
export 'package:connection_engine/connection_engine.dart';
export 'package:printer_protocols/printer_protocols.dart'
    show PrinterCredentials;

export 'src/api_mapping.dart';
export 'src/printer_family.dart';
export 'src/printers_repository.dart';
