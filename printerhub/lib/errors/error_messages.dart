import 'package:api_client/api_client.dart';
import 'package:printerhub/l10n/l10n.dart';

/// The sentence shown to the user for [error].
///
/// This is the one place an API error code becomes words, so the same
/// failure reads the same on every screen.
String errorMessage(AppLocalizations l10n, Object? error) {
  if (error is ApiUnreachable) return l10n.errorUnreachable;
  if (error is! ApiProblem) return l10n.errorGeneric;

  return switch (error.code) {
    'auth.invalid_credentials' => l10n.errorInvalidCredentials,
    'auth.email_taken' => l10n.errorEmailTaken,
    'auth.code_invalid' => l10n.errorCodeInvalid,
    'auth.current_password_incorrect' ||
    'account.password_incorrect' => l10n.errorPasswordIncorrect,
    'account.sole_owner' => l10n.errorSoleOwner,
    'rate_limited' => l10n.errorRateLimited,
    'auth.email_not_verified' => l10n.errorEmailNotVerified,
    'pairing.token_invalid' => l10n.errorPairingInvalid,
    'pairing.not_a_member' => l10n.errorPairingNotMember,
    'request.validation_failed' =>
      error.fieldErrors.firstOrNull?.message ?? l10n.errorGeneric,
    _ => error.detail ?? l10n.errorGeneric,
  };
}
