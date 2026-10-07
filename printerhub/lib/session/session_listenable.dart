import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:printerhub/session/cubit/session_cubit.dart';

/// Tells the router to look again whenever the session reaches another
/// stage.
class SessionListenable extends ChangeNotifier {
  new(SessionCubit cubit) : _stage = cubit.state.stage {
    // Only the stage decides where someone belongs. Reacting to every
    // change (a renamed user, a verified email) would make the router
    // rebuild its stack while a screen is closing itself.
    _subscription = cubit.stream.listen((state) {
      if (state.stage == _stage) return;
      _stage = state.stage;
      notifyListeners();
    });
  }

  SessionStage _stage;
  late final StreamSubscription<SessionState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
