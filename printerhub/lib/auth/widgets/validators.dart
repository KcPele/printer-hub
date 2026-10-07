import 'package:printerhub/l10n/l10n.dart';

/// What each form field accepts. A validator returns the sentence to show
/// under the field, or null when the value is fine.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _code = RegExp(r'^\d{6}$');

  /// The shortest password the API accepts.
  static const int minPasswordLength = 8;

  static String? email(AppLocalizations l10n, String? value) {
    return _email.hasMatch(value?.trim() ?? '') ? null : l10n.validationEmail;
  }

  /// For signing in: any password is allowed, an empty one is not.
  static String? password(AppLocalizations l10n, String? value) {
    return (value ?? '').isEmpty ? l10n.validationPassword : null;
  }

  /// For choosing a password.
  static String? newPassword(AppLocalizations l10n, String? value) {
    return (value ?? '').length < minPasswordLength
        ? l10n.validationPasswordLength
        : null;
  }

  static String? name(AppLocalizations l10n, String? value) {
    return (value ?? '').trim().isEmpty ? l10n.validationName : null;
  }

  static String? code(AppLocalizations l10n, String? value) {
    return _code.hasMatch(value?.trim() ?? '') ? null : l10n.validationCode;
  }

  static String? workspace(AppLocalizations l10n, String? value) {
    return (value ?? '').trim().isEmpty ? l10n.validationWorkspace : null;
  }
}
