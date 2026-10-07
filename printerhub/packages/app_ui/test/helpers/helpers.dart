import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

extension PumpThemed on WidgetTester {
  /// Pumps [widget] inside [theme], centred on a scaffold.
  Future<void> pumpThemed(Widget widget, {AppTheme theme = AppTheme.volt}) {
    return pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.data(),
        home: Scaffold(body: Center(child: widget)),
      ),
    );
  }
}
