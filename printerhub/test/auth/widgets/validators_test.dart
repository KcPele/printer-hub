import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/auth/auth.dart';
import 'package:printerhub/l10n/l10n.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('Validators', () {
    test('email needs something that looks like an address', () {
      expect(Validators.email(l10n, 'ada@example.com'), isNull);
      expect(Validators.email(l10n, '  ada@example.com '), isNull);
      for (final value in [null, '', 'ada', 'ada@', 'ada@example', 'a b@c.d']) {
        expect(Validators.email(l10n, value), l10n.validationEmail);
      }
    });

    test('password for signing in only has to be there', () {
      expect(Validators.password(l10n, 'x'), isNull);
      expect(Validators.password(l10n, ''), l10n.validationPassword);
      expect(Validators.password(l10n, null), l10n.validationPassword);
    });

    test('a new password needs eight characters', () {
      expect(Validators.newPassword(l10n, '12345678'), isNull);
      expect(
        Validators.newPassword(l10n, '1234567'),
        l10n.validationPasswordLength,
      );
      expect(Validators.newPassword(l10n, null), l10n.validationPasswordLength);
    });

    test('name cannot be blank', () {
      expect(Validators.name(l10n, 'Ada'), isNull);
      expect(Validators.name(l10n, '   '), l10n.validationName);
      expect(Validators.name(l10n, null), l10n.validationName);
    });

    test('code is six digits', () {
      expect(Validators.code(l10n, '123456'), isNull);
      expect(Validators.code(l10n, ' 123456 '), isNull);
      for (final value in [null, '', '12345', '1234567', '12345a']) {
        expect(Validators.code(l10n, value), l10n.validationCode);
      }
    });

    test('workspace name cannot be blank', () {
      expect(Validators.workspace(l10n, 'Acme'), isNull);
      expect(Validators.workspace(l10n, ' '), l10n.validationWorkspace);
      expect(Validators.workspace(l10n, null), l10n.validationWorkspace);
    });
  });
}
