import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';

/// A family of printers in the catalogue: what its models have in common,
/// and what to do on one before adding it.
///
/// A family is a guide. What a particular printer can do comes from asking
/// the printer.
class PrinterFamily extends Equatable {
  const new({
    required this.id,
    required this.manufacturer,
    required this.name,
    required this.category,
    this.summary,
    this.setupTips = const [],
    this.color = false,
    this.duplex = false,
    this.scans = false,
    this.feeder = false,
  });

  factory fromApi(CapabilityProfileRead profile) {
    final print = profile.capabilities.print;
    final scan = profile.capabilities.scan;
    return PrinterFamily(
      id: profile.id,
      manufacturer: profile.manufacturer,
      name: profile.displayName,
      category: profile.category.json ?? 'office_multifunction',
      summary: profile.summary,
      setupTips: profile.setupTips,
      color: print.color,
      duplex: print.duplexModes.any((mode) => mode != DuplexMode.oneSided),
      scans: scan.supported,
      feeder: scan.sources.contains(ScanSource.adf),
    );
  }

  final String id;
  final String manufacturer;

  /// The family's name without its maker: "LaserJet Pro MFP".
  final String name;

  /// `office_multifunction`, `office_printer`, `home_multifunction`, or
  /// `home_printer`.
  final String category;

  /// One line saying what the family is.
  final String? summary;

  /// What to do on the printer so it can be found and used, in order.
  final List<String> setupTips;

  /// What the family's models usually do.
  final bool color;
  final bool duplex;
  final bool scans;
  final bool feeder;

  /// The maker and the family together: "HP LaserJet Pro MFP".
  String get title => '$manufacturer $name';

  /// True for the printers people have at home.
  bool get isHome => category.startsWith('home');

  /// True when [query] names this family or its maker. An empty query
  /// matches everything.
  bool matches(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+'));
    final text = '$title ${summary ?? ''}'.toLowerCase();
    return words.every(text.contains);
  }

  @override
  List<Object?> get props => [
    id,
    manufacturer,
    name,
    category,
    summary,
    setupTips,
    color,
    duplex,
    scans,
    feeder,
  ];
}
