import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/session/session.dart';

import '../helpers/helpers.dart';

void main() {
  test('SessionListenable notifies when the session changes stage', () async {
    final backend = TestBackend();
    addTearDown(backend.close);
    final cubit = SessionCubit(
      authRepository: backend.auth,
      organizationsRepository: backend.organizations,
      preferencesRepository: emptyPreferences(),
    );
    addTearDown(cubit.close);
    final listenable = SessionListenable(cubit);
    var notifications = 0;
    listenable.addListener(() => notifications++);

    await backend.auth.signIn(email: 'ada@example.com', password: 'pw');
    await pumpEventQueue();
    expect(notifications, 2);

    // A change that leaves the stage alone is not announced.
    await backend.auth.updateName('Ada L.');
    await pumpEventQueue();
    expect(notifications, 2);

    listenable.dispose();
    await backend.auth.signOut();
    await pumpEventQueue();
    expect(notifications, 2);
  });
}
