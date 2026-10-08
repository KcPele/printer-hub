import 'dart:ui';

import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  ApiProblem problem(
    String code, {
    String? detail,
    List<ApiFieldError> fieldErrors = const [],
  }) {
    return ApiProblem(
      status: 400,
      code: code,
      title: 'Error',
      detail: detail,
      fieldErrors: fieldErrors,
    );
  }

  group('errorMessage', () {
    test('says the API cannot be reached', () {
      expect(
        errorMessage(l10n, const ApiUnreachable(cause: 'timeout')),
        l10n.errorUnreachable,
      );
    });

    test('has a sentence for each code the app expects', () {
      final expected = {
        'auth.invalid_credentials': l10n.errorInvalidCredentials,
        'auth.email_taken': l10n.errorEmailTaken,
        'auth.code_invalid': l10n.errorCodeInvalid,
        'auth.current_password_incorrect': l10n.errorPasswordIncorrect,
        'account.password_incorrect': l10n.errorPasswordIncorrect,
        'account.sole_owner': l10n.errorSoleOwner,
        'rate_limited': l10n.errorRateLimited,
        'pairing.token_invalid': l10n.errorPairingInvalid,
        'pairing.not_a_member': l10n.errorPairingNotMember,
      };

      for (final MapEntry(key: code, value: message) in expected.entries) {
        expect(errorMessage(l10n, problem(code)), message, reason: code);
      }
    });

    test('names the first rejected field of an invalid request', () {
      final invalid = problem(
        'request.validation_failed',
        fieldErrors: const [
          ApiFieldError(field: 'email', message: 'Not an email', code: 'x'),
          ApiFieldError(field: 'name', message: 'Too long', code: 'y'),
        ],
      );

      expect(errorMessage(l10n, invalid), 'Not an email');
      expect(
        errorMessage(l10n, problem('request.validation_failed')),
        l10n.errorGeneric,
      );
    });

    test('uses what the API said for a code it does not know', () {
      expect(
        errorMessage(l10n, problem('printer.busy', detail: 'Printer is busy.')),
        'Printer is busy.',
      );
      expect(errorMessage(l10n, problem('printer.busy')), l10n.errorGeneric);
    });

    test('has a fallback for anything else', () {
      expect(errorMessage(l10n, StateError('bug')), l10n.errorGeneric);
      expect(errorMessage(l10n, null), l10n.errorGeneric);
    });
  });
}
