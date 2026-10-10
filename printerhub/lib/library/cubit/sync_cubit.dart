import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/library/library.dart';

class SyncState extends Equatable {
  const new({this.waiting = 0, this.syncing = false, this.lastSynced});

  /// How many things made on this phone the account does not have yet.
  final int waiting;

  /// True while they are being sent.
  final bool syncing;

  /// When everything last reached the account. Null when it never has.
  final DateTime? lastSynced;

  @override
  List<Object?> get props => [waiting, syncing, lastSynced];
}

/// Sends what was made on this phone to the person's account, for the
/// whole app: when a workspace is opened, when the app comes back to the
/// front, every few minutes while it is open, and when asked.
class SyncCubit extends Cubit<SyncState> {
  new({
    required this._library,
    required Stream<String?> organizationChanges,
    this._organizationId,
    Duration? every = const Duration(minutes: 5),
  }) : super(_counted(_library, _organizationId)) {
    _changes = _library.changes.listen((_) => _count());
    _organizations = organizationChanges.listen((organizationId) {
      _organizationId = organizationId;
      unawaited(sync());
    });
    // With no interval it is sent only when asked.
    if (every != null) {
      _timer = Timer.periodic(every, (_) => unawaited(sync()));
    }
  }

  final Library _library;
  String? _organizationId;
  late final StreamSubscription<void> _changes;
  late final StreamSubscription<String?> _organizations;
  Timer? _timer;

  /// What waited when the app was last closed is counted at once.
  static SyncState _counted(Library library, String? organizationId) {
    library.open();
    return organizationId == null
        ? const SyncState()
        : SyncState(
            waiting: library.waiting(organizationId),
            lastSynced: library.lastSynced(organizationId),
          );
  }

  void _count({bool syncing = false}) {
    final organizationId = _organizationId;
    if (isClosed) return;
    emit(
      organizationId == null
          ? const SyncState()
          : SyncState(
              waiting: _library.waiting(organizationId),
              syncing: syncing || state.syncing,
              lastSynced: _library.lastSynced(organizationId),
            ),
    );
  }

  /// Sends what is waiting. With no workspace there is nothing to send
  /// to.
  Future<void> sync() async {
    final organizationId = _organizationId;
    if (organizationId == null) {
      _count();
      return;
    }
    if (state.syncing) return;
    _count(syncing: true);
    try {
      await _library.sync(organizationId);
    } finally {
      if (!isClosed) {
        emit(
          SyncState(
            waiting: _library.waiting(organizationId),
            lastSynced: _library.lastSynced(organizationId),
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _changes.cancel();
    await _organizations.cancel();
    await super.close();
  }
}
