import 'package:material_ui/material_ui.dart';

/// How a theme lifts a card off the background: a shadow, a border, or
/// neither.
@immutable
class AppDepth extends ThemeExtension<AppDepth> {
  const new({required this.cardShadow, required this.cardBorder});

  /// No shadow and no border. The card stands out by colour alone.
  static const AppDepth flat = AppDepth(
    cardShadow: [],
    cardBorder: BorderSide.none,
  );

  final List<BoxShadow> cardShadow;
  final BorderSide cardBorder;

  @override
  AppDepth copyWith({List<BoxShadow>? cardShadow, BorderSide? cardBorder}) {
    return AppDepth(
      cardShadow: cardShadow ?? this.cardShadow,
      cardBorder: cardBorder ?? this.cardBorder,
    );
  }

  @override
  AppDepth lerp(AppDepth? other, double t) {
    if (other == null) return this;
    return AppDepth(
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
      cardBorder: BorderSide.lerp(cardBorder, other.cardBorder, t),
    );
  }
}
