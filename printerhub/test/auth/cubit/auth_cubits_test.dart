import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/auth/auth.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() => backend = TestBackend());
  tearDown(() => backend.close());

  const inProgress = SubmitState(status: SubmitStatus.inProgress);
  const success = SubmitState(status: SubmitStatus.success);

  group('SubmitState', () {
    test('says where the submission stands', () {
      expect(const SubmitState().inProgress, isFalse);
      expect(inProgress.inProgress, isTrue);
      expect(success.succeeded, isTrue);
      expect(const SubmitState(status: SubmitStatus.failure).failed, isTrue);
    });
  });

  group('SignInCubit', () {
    blocTest<SignInCubit, SubmitState>(
      'signs in',
      build: () => SignInCubit(authRepository: backend.auth),
      act: (cubit) => cubit.submit(email: 'ada@example.com', password: 'pw'),
      expect: () => [inProgress, success],
      verify: (_) {
        expect(backend.auth.user?.email, 'ada@example.com');
        expect(backend.lastBody('POST /auth/login'), {
          'email': 'ada@example.com',
          'password': 'pw',
        });
      },
    );

    blocTest<SignInCubit, SubmitState>(
      'reports why signing in failed',
      setUp: () =>
          backend.fail('POST /auth/login', 401, 'auth.invalid_credentials'),
      build: () => SignInCubit(authRepository: backend.auth),
      act: (cubit) => cubit.submit(email: 'ada@example.com', password: 'no'),
      expect: () => [
        inProgress,
        isA<SubmitState>()
            .having((state) => state.failed, 'failed', isTrue)
            .having(
              (state) => (state.error! as ApiProblem).code,
              'code',
              'auth.invalid_credentials',
            ),
      ],
    );

    blocTest<SignInCubit, SubmitState>(
      'reports that the API cannot be reached',
      setUp: () => backend.offline = true,
      build: () => SignInCubit(authRepository: backend.auth),
      act: (cubit) => cubit.submit(email: 'ada@example.com', password: 'pw'),
      expect: () => [
        inProgress,
        isA<SubmitState>().having(
          (state) => state.error,
          'error',
          isA<ApiUnreachable>(),
        ),
      ],
    );

    test('ignores a second submission while the first is out', () async {
      final gate = Completer<void>();
      backend.routes['POST /auth/login'] = (_) async {
        await gate.future;
        return FakeResponse(200, {
          'user': userBody(),
          'tokens': tokenResponse('a', 'r'),
        });
      };
      final cubit = SignInCubit(authRepository: backend.auth);

      final first = cubit.submit(email: 'ada@example.com', password: 'pw');
      await cubit.submit(email: 'ada@example.com', password: 'pw');
      gate.complete();
      await first;

      expect(backend.sent('POST /auth/login'), hasLength(1));
      expect(cubit.state, success);
      await cubit.close();
    });
  });

  blocTest<RegisterCubit, SubmitState>(
    'RegisterCubit creates the account',
    build: () => RegisterCubit(authRepository: backend.auth),
    act: (cubit) => cubit.submit(
      name: 'Grace',
      email: 'grace@example.com',
      password: 'long enough',
    ),
    expect: () => [inProgress, success],
    verify: (_) => expect(backend.auth.user?.name, 'Grace'),
  );

  blocTest<ForgotPasswordCubit, SubmitState>(
    'ForgotPasswordCubit asks for a code',
    build: () => ForgotPasswordCubit(authRepository: backend.auth),
    act: (cubit) => cubit.submit(email: 'ada@example.com'),
    expect: () => [inProgress, success],
    verify: (_) => expect(backend.lastBody('POST /auth/password/forgot'), {
      'email': 'ada@example.com',
    }),
  );

  blocTest<ResetPasswordCubit, SubmitState>(
    'ResetPasswordCubit sets the new password',
    build: () => ResetPasswordCubit(authRepository: backend.auth),
    act: (cubit) => cubit.submit(
      email: 'ada@example.com',
      code: '123456',
      newPassword: 'new password',
    ),
    expect: () => [inProgress, success],
    verify: (_) => expect(backend.lastBody('POST /auth/password/reset'), {
      'email': 'ada@example.com',
      'code': '123456',
      'new_password': 'new password',
    }),
  );

  group('when signed in', () {
    setUp(() => backend.signedInBefore());

    blocTest<VerifyEmailCubit, SubmitState>(
      'VerifyEmailCubit verifies the address',
      build: () => VerifyEmailCubit(authRepository: backend.auth),
      act: (cubit) => cubit.submit(code: '123456'),
      expect: () => [inProgress, success],
      verify: (_) => expect(backend.auth.user?.emailVerified, isTrue),
    );

    blocTest<ResendCodeCubit, SubmitState>(
      'ResendCodeCubit asks for another code',
      build: () => ResendCodeCubit(authRepository: backend.auth),
      act: (cubit) => cubit.submit(),
      expect: () => [inProgress, success],
      verify: (_) =>
          expect(backend.sent('POST /auth/email/resend'), hasLength(1)),
    );
  });
}
