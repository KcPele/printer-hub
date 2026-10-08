import 'package:api_client/api_client.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/account/account.dart';
import 'package:printerhub/auth/cubit/submit_cubit.dart';

import '../../helpers/helpers.dart';

void main() {
  late TestBackend backend;

  setUp(() async {
    backend = TestBackend();
    await backend.signedInBefore();
  });
  tearDown(() => backend.close());

  const succeeded = [
    SubmitState(status: SubmitStatus.inProgress),
    SubmitState(status: SubmitStatus.success),
  ];

  blocTest<UpdateNameCubit, SubmitState>(
    'UpdateNameCubit changes the name on the account',
    build: () => UpdateNameCubit(authRepository: backend.auth),
    act: (cubit) => cubit.submit(name: 'Ada Lovelace'),
    expect: () => succeeded,
    verify: (_) {
      expect(backend.user['name'], 'Ada Lovelace');
      expect(backend.auth.user!.name, 'Ada Lovelace');
    },
  );

  blocTest<ChangePasswordCubit, SubmitState>(
    'ChangePasswordCubit sends the old password and the new',
    build: () => ChangePasswordCubit(authRepository: backend.auth),
    act: (cubit) =>
        cubit.submit(currentPassword: 'old one', newPassword: 'new one 123'),
    expect: () => succeeded,
    verify: (_) => expect(backend.network.requests.last.data, {
      'current_password': 'old one',
      'new_password': 'new one 123',
    }),
  );

  blocTest<ChangePasswordCubit, SubmitState>(
    'ChangePasswordCubit says when the current password is wrong',
    setUp: () => backend.fail(
      'POST /auth/password/change',
      401,
      'auth.invalid_credentials',
    ),
    build: () => ChangePasswordCubit(authRepository: backend.auth),
    act: (cubit) => cubit.submit(currentPassword: 'x', newPassword: 'y'),
    skip: 1,
    expect: () => [
      isA<SubmitState>()
          .having((s) => s.failed, 'failed', isTrue)
          .having((s) => s.error, 'error', isA<ApiProblem>()),
    ],
  );

  blocTest<DeleteAccountCubit, SubmitState>(
    'DeleteAccountCubit deletes the account and ends the session',
    build: () => DeleteAccountCubit(authRepository: backend.auth),
    act: (cubit) => cubit.submit(password: 'correct horse'),
    expect: () => succeeded,
    verify: (_) => expect(backend.auth.user, isNull),
  );
}
