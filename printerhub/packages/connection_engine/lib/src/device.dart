import 'package:equatable/equatable.dart';

/// A way to reach a device: a protocol at an address.
class DeviceConnection extends Equatable {
  const new({required this.type, required this.uri});

  /// `ipp`, `ipps`, or `escl`.
  final String type;

  /// Where the protocol answers. For eSCL this is the `/eSCL` root.
  final Uri uri;

  bool get isSecure => uri.scheme == 'ipps' || uri.scheme == 'https';

  /// What this connection is used for: `print`, `scan`, `status`.
  List<String> get purposes =>
      type == 'escl' ? const ['scan'] : const ['print', 'status'];

  @override
  List<Object> get props => [type, uri];
}

/// What a device can print.
class PrintFeatures extends Equatable {
  const new({
    this.color = false,
    this.duplexModes = const ['one_sided'],
    this.documentFormats = const [],
    this.mediaSizes = const [],
    this.mediaTypes = const [],
    this.trays = const [],
    this.maxCopies,
    this.resolutionsDpi = const [],
    this.qualities = const [],
    this.collation = false,
    this.airPrint = false,
  });

  final bool color;

  /// `one_sided`, `two_sided_long_edge`, `two_sided_short_edge`.
  final List<String> duplexModes;
  final List<String> documentFormats;

  /// PWG media names, such as `iso_a4_210x297mm`.
  final List<String> mediaSizes;
  final List<String> mediaTypes;

  /// Tray identifiers, such as `tray-1`.
  final List<String> trays;
  final int? maxCopies;
  final List<int> resolutionsDpi;

  /// `draft`, `normal`, `high`.
  final List<String> qualities;
  final bool collation;

  /// True when the device accepts the raster format AirPrint sends.
  final bool airPrint;

  bool get duplex => duplexModes.any((mode) => mode != 'one_sided');

  @override
  List<Object?> get props => [
    color,
    duplexModes,
    documentFormats,
    mediaSizes,
    mediaTypes,
    trays,
    maxCopies,
    resolutionsDpi,
    qualities,
    collation,
    airPrint,
  ];
}

/// What a device can scan.
class ScanFeatures extends Equatable {
  const new({
    this.sources = const [],
    this.feederDuplex = false,
    this.colorModes = const [],
    this.documentFormats = const [],
    this.resolutionsDpi = const [],
    this.maxWidthMm,
    this.maxHeightMm,
  });

  /// `platen` (the glass) and `adf` (the feeder).
  final List<String> sources;
  final bool feederDuplex;

  /// `color`, `grayscale`, `monochrome`.
  final List<String> colorModes;
  final List<String> documentFormats;
  final List<int> resolutionsDpi;
  final double? maxWidthMm;
  final double? maxHeightMm;

  bool get hasGlass => sources.contains('platen');
  bool get hasFeeder => sources.contains('adf');

  @override
  List<Object?> get props => [
    sources,
    feederDuplex,
    colorModes,
    documentFormats,
    resolutionsDpi,
    maxWidthMm,
    maxHeightMm,
  ];
}

/// A toner, ink, or other supply and how much is left.
class Supply extends Equatable {
  const new({
    required this.name,
    required this.kind,
    this.color,
    this.levelPercent,
  });

  final String name;

  /// Such as `toner`, `ink`, `drum`, `waste`.
  final String kind;

  /// `cyan`, `magenta`, `yellow`, `black`, or whatever the device reports.
  final String? color;
  final int? levelPercent;

  /// `ok`, `low` at 10% or less, `empty` at 0, `unknown`.
  String get state => switch (levelPercent) {
    null => 'unknown',
    0 => 'empty',
    <= 10 => 'low',
    _ => 'ok',
  };

  @override
  List<Object?> get props => [name, kind, color, levelPercent];
}

/// Something the device wants attention for.
class DeviceAlert extends Equatable {
  const new({required this.code, required this.severity});

  /// The device's own keyword, without its severity suffix: `media-jam`,
  /// `toner-low`, `door-open`.
  final String code;

  /// `error`, `warning`, or `info`.
  final String severity;

  @override
  List<Object> get props => [code, severity];
}

/// What a device is doing right now.
class DeviceStatus extends Equatable {
  const new({
    required this.state,
    this.acceptingJobs = true,
    this.supplies = const [],
    this.alerts = const [],
    this.scannerState = 'unknown',
  });

  /// The device could not be reached.
  static const DeviceStatus unreachable = DeviceStatus(
    state: 'unreachable',
    acceptingJobs: false,
  );

  /// `online`, `offline`, `unreachable`, or `unknown`.
  final String state;
  final bool acceptingJobs;
  final List<Supply> supplies;
  final List<DeviceAlert> alerts;

  /// `idle`, `busy`, `error`, `unavailable`, or `unknown`.
  final String scannerState;

  bool get hasError => alerts.any((alert) => alert.severity == 'error');

  @override
  List<Object> get props => [
    state,
    acceptingJobs,
    supplies,
    alerts,
    scannerState,
  ];
}

/// Everything learned about a device by asking it.
class DeviceDescription extends Equatable {
  const new({
    required this.host,
    required this.connections,
    this.name,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.uuid,
    this.print,
    this.scan,
    this.status = const DeviceStatus(state: 'unknown'),
  });

  final String host;

  /// The connections that answered, in the order they should be tried.
  final List<DeviceConnection> connections;

  /// The name the device gives itself.
  final String? name;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final String? uuid;

  /// Null when the device does not print over a protocol the app speaks.
  final PrintFeatures? print;

  /// Null when the device does not scan over a protocol the app speaks.
  final ScanFeatures? scan;
  final DeviceStatus status;

  /// The best name to show before the user gives one.
  String get displayName =>
      [manufacturer, model].whereType<String>().join(' ').trim().isNotEmpty
      ? [manufacturer, model].whereType<String>().join(' ')
      : name ?? host;

  @override
  List<Object?> get props => [
    host,
    connections,
    name,
    manufacturer,
    model,
    serialNumber,
    uuid,
    print,
    scan,
    status,
  ];
}
