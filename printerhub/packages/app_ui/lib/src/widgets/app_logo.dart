import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The PrinterHub mark on its tile, as on the launch screen.
///
/// Its colours are the brand's and do not follow the theme: it is the same
/// picture the phone shows before the app has chosen one.
class AppLogo extends StatelessWidget {
  const new({this.size = 96, this.semanticLabel, super.key});

  final double size;

  /// What to call the picture for screen readers. Without one it is
  /// decoration and is hidden from them.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/tile.svg',
      package: 'app_ui',
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
