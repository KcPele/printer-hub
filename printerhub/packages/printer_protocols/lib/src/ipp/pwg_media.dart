import 'package:meta/meta.dart';

/// A paper size, read from its PWG name. The names carry their own
/// measurements: `iso_a4_210x297mm`, `na_letter_8.5x11in`.
@immutable
class PwgMedia {
  const new(this.name, this.widthHundredthsMm, this.heightHundredthsMm);

  /// Null when [name] does not end in measurements.
  static PwgMedia? parse(String name) {
    final match = _measurements.firstMatch(name);
    if (match == null) return null;
    final perUnit = match.group(3) == 'in' ? 2540 : 100;
    final width = double.parse(match.group(1)!) * perUnit;
    final height = double.parse(match.group(2)!) * perUnit;
    if (width <= 0 || height <= 0) return null;
    return PwgMedia(name, width.round(), height.round());
  }

  static final RegExp _measurements = RegExp(
    r'_(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)(mm|in)$',
  );

  final String name;

  /// IPP measures paper in hundredths of a millimetre.
  final int widthHundredthsMm;
  final int heightHundredthsMm;

  /// How many pixels cross the sheet at [dpi].
  int widthPx(int dpi) => (widthHundredthsMm * dpi / 2540).round();

  /// How many pixels run down the sheet at [dpi].
  int heightPx(int dpi) => (heightHundredthsMm * dpi / 2540).round();

  @override
  bool operator ==(Object other) {
    return other is PwgMedia &&
        other.name == name &&
        other.widthHundredthsMm == widthHundredthsMm &&
        other.heightHundredthsMm == heightHundredthsMm;
  }

  @override
  int get hashCode => Object.hash(name, widthHundredthsMm, heightHundredthsMm);

  @override
  String toString() => name;
}
