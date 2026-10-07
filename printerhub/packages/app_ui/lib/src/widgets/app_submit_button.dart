import 'package:material_ui/material_ui.dart';

/// The main button of a form. While [loading] it shows progress and cannot
/// be pressed again.
class AppSubmitButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  semanticsLabel: label,
                ),
              )
            : Text(label),
      ),
    );
  }
}
