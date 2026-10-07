import 'package:api_client/api_client.dart';
import 'package:connection_engine/connection_engine.dart';

/// Keeps the values an API enum knows and drops the rest. Sending a value
/// the API does not know would be refused.
List<E> _known<E extends Enum>(
  Iterable<String> values,
  E Function(String) parse,
  E unknown,
) {
  return [
    for (final value in values)
      if (parse(value) != unknown) parse(value),
  ];
}

/// A connection the device answered on, as the API stores it.
ConnectionCreate connectionToApi(DeviceConnection connection, int priority) {
  return ConnectionCreate(
    type: ConnectionType.fromJson(connection.type),
    purposes: _known(
      connection.purposes,
      ConnectionPurpose.fromJson,
      ConnectionPurpose.$unknown,
    ),
    priority: priority,
    configuration: ConnectionConfigurationInput(
      host: connection.uri.host,
      port: connection.uri.port,
      path: connection.uri.path,
      tls: connection.isSecure,
    ),
  );
}

/// A stored connection, as the address the device answers on. Null for a
/// kind of connection the app does not open itself, such as AirPrint.
DeviceConnection? connectionFromApi(ConnectionRead connection) {
  final configuration = connection.configuration;
  final host = configuration.host;
  final type = connection.type.json;
  if (host == null || host.isEmpty) return null;

  final secure = configuration.tls ?? type == 'ipps';
  switch (type) {
    case 'ipp' || 'ipps':
      return DeviceConnection(
        type: type!,
        uri: Uri(
          scheme: type,
          host: host,
          port: configuration.port ?? 631,
          path: configuration.path ?? '/ipp/print',
        ),
      );
    case 'escl':
      return DeviceConnection(
        type: 'escl',
        uri: Uri(
          scheme: secure ? 'https' : 'http',
          host: host,
          port: configuration.port ?? (secure ? 443 : 80),
          path: configuration.path ?? '/eSCL',
        ),
      );
  }
  return null;
}

/// What the device can do, as the API stores it.
PrinterCapabilitiesInput capabilitiesToApi(DeviceDescription device) {
  final print = device.print;
  final scan = device.scan;
  final types = device.connections.map((connection) => connection.type);

  return PrinterCapabilitiesInput(
    print: print == null
        ? null
        : PrintCapabilitiesInput(
            supported: true,
            color: print.color,
            collation: print.collation,
            duplexModes: _known(
              print.duplexModes,
              DuplexMode.fromJson,
              DuplexMode.$unknown,
            ),
            documentFormats: print.documentFormats,
            mediaSizes: print.mediaSizes,
            mediaTypes: print.mediaTypes,
            qualityModes: print.qualities,
            resolutionsDpi: print.resolutionsDpi,
            maxCopies: print.maxCopies,
            trays: [
              for (final tray in print.trays)
                MediaTrayInput(id: tray, name: tray),
            ],
          ),
    scan: scan == null
        ? null
        : ScanCapabilitiesInput(
            supported: true,
            adfDuplex: scan.feederDuplex,
            sources: _known(
              scan.sources,
              ScanSource.fromJson,
              ScanSource.$unknown,
            ),
            colorModes: _known(
              scan.colorModes,
              ScanColorMode.fromJson,
              ScanColorMode.$unknown,
            ),
            documentFormats: scan.documentFormats,
            resolutionsDpi: scan.resolutionsDpi,
            maxWidthMm: scan.maxWidthMm,
            maxHeightMm: scan.maxHeightMm,
          ),
    // Copying is scanning then printing, done by the app.
    copy: CopyCapabilitiesInput(supported: print != null && scan != null),
    status: StatusCapabilitiesInput(
      reporting: print != null,
      consumables: device.status.supplies.isNotEmpty,
    ),
    protocols: ProtocolsInput(
      ipp: types.contains('ipp'),
      ipps: types.contains('ipps'),
      escl: types.contains('escl'),
      airprint: print?.airPrint ?? false,
    ),
  );
}

/// Everything needed to add [device] to a workspace.
PrinterCreate printerToApi(
  DeviceDescription device, {
  required String name,
  String? location,
}) {
  return PrinterCreate(
    friendlyName: name,
    location: location == null || location.trim().isEmpty ? null : location,
    manufacturer: device.manufacturer,
    model: device.model,
    serialNumber: device.serialNumber,
    capabilities: capabilitiesToApi(device),
    connections: [
      for (final (index, connection) in device.connections.indexed)
        // Priorities start at 1: the first connection is tried first.
        connectionToApi(connection, index + 1),
    ],
  );
}

/// What the device is doing, as the API stores it.
PrinterStatusReport statusToApi(DeviceStatus status) {
  final state = PrinterStatus.fromJson(status.state);
  final scanner = PrinterStatusDetailInputScannerState.fromJson(
    status.scannerState,
  );

  return PrinterStatusReport(
    status: state == PrinterStatus.$unknown ? PrinterStatus.unknown : state,
    detail: PrinterStatusDetailInput(
      scannerState: scanner == PrinterStatusDetailInputScannerState.$unknown
          ? PrinterStatusDetailInputScannerState.unknown
          : scanner,
      consumables: [
        for (final supply in status.supplies)
          ConsumableInput(
            name: supply.name,
            kind: supply.kind,
            color: supply.color,
            levelPercent: supply.levelPercent,
            state: ConsumableInputState.fromJson(supply.state),
          ),
      ],
      alerts: [
        for (final alert in status.alerts)
          DeviceAlertInput(
            code: alert.code,
            severity: DeviceAlertInputSeverity.fromJson(alert.severity),
          ),
      ],
    ),
  );
}
