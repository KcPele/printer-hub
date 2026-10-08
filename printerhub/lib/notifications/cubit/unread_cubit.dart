import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:notifications_repository/notifications_repository.dart';

/// How many notifications the account has not read, for the badge.
///
/// It counts again when someone signs in, when something is read, and
/// whenever it is asked to: the app asks as it comes back to the front.
class UnreadCubit extends Cubit<int> {
  new({
    required this._notificationsRepository,
    required Stream<bool> signedInChanges,
    this._signedIn = false,
  }) : super(0) {
    _changes = _notificationsRepository.changes.listen(
      (_) => unawaited(refresh()),
    );
    _sessions = signedInChanges.listen((signedIn) {
      _signedIn = signedIn;
      if (signedIn) {
        unawaited(refresh());
      } else {
        emit(0);
      }
    });
  }

  final NotificationsRepository _notificationsRepository;
  late final StreamSubscription<void> _changes;
  late final StreamSubscription<bool> _sessions;
  bool _signedIn;

  /// Counts again. A count that cannot be had leaves the badge as it is.
  Future<void> refresh() async {
    if (!_signedIn) return;
    try {
      final unread = await _notificationsRepository.unreadCount();
      if (!isClosed && _signedIn) emit(unread);
    } on ApiException {
      // The next count brings it up to date.
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    await _sessions.cancel();
    await super.close();
  }
}
