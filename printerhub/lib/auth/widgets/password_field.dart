import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';

/// A password field with a button to reveal what was typed.
class PasswordField extends StatefulWidget {
  const new({
    required this.controller,
    required this.label,
    required this.validator,
    this.isNew = false,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;

  /// True when choosing a password, so password managers offer to make one.
  final bool isNew;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      validator: widget.validator,
      autofillHints: [
        if (widget.isNew) AutofillHints.newPassword else AutofillHints.password,
      ],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _hidden ? l10n.fieldShowPassword : l10n.fieldHidePassword,
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}
