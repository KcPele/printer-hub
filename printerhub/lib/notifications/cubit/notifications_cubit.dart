import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:printerhub/app/remembered.dart';

enum NotificationsStatus { loading, ready, failed }

class NotificationsState extends Equatable {
  const new({
    this.status = NotificationsStatus.loading,
    this.notifications = const [],
    this.next,
    this.loadingMore = false,
    this.error,
  });

  final NotificationsStatus status;

  /// What the account was told, newest first, as far as read.
  final List<AppNotification> notifications;

  /// Where the next page starts. Null when there is no more.
  final String? next;
  final bool loadingMore;

  /// Why the list could not be read. Pass it to `errorMessage`.
  final ApiException? error;

  bool get hasUnread => notifications.any((one) => !one.isRead);

  @override
  List<Object?> get props => [status, notifications, next, loadingMore, error];
}

/// What the account has been told, and marking it read.
class NotificationsCubit extends Cubit<NotificationsState> {
  new({required this._notificationsRepository, this._remembered})
    : super(
        _remembered?.of<NotificationsState>(_key) ?? const NotificationsState(),
      );

  static const String _key = 'notifications';

  final NotificationsRepository _notificationsRepository;

  /// Where the list is kept between visits, so the screen opens on what
  /// it showed last and not on a wait.
  final Remembered? _remembered;

  @override
  void onChange(Change<NotificationsState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (next.status == NotificationsStatus.ready && next.error == null) {
      _remembered?.keep(_key, next);
    }
  }

  /// Reads the list. What is already shown stays until the news is in.
  Future<void> load() async {
    final shown = state.status == NotificationsStatus.ready;
    if (!shown) emit(const NotificationsState());
    try {
      final page = await _notificationsRepository.list();
      if (isClosed) return;
      emit(
        NotificationsState(
          status: NotificationsStatus.ready,
          notifications: page.notifications,
          next: page.next,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(
        shown
            // What was read before is still worth showing.
            ? _with(error: error)
            : NotificationsState(
                status: NotificationsStatus.failed,
                error: error,
              ),
      );
    }
  }

  /// Reads the next page.
  Future<void> more() async {
    final cursor = state.next;
    if (cursor == null || state.loadingMore) return;
    emit(_with(loadingMore: true));
    try {
      final page = await _notificationsRepository.list(cursor: cursor);
      if (isClosed) return;
      emit(
        _with(
          notifications: [...state.notifications, ...page.notifications],
          next: () => page.next,
        ),
      );
    } on ApiException catch (error) {
      if (!isClosed) emit(_with(error: error));
    }
  }

  /// Marks one read. It is read on the screen at once: the person has
  /// seen it, whether or not the API could be told just now.
  Future<void> read(AppNotification notification) async {
    if (notification.isRead) return;
    _show({notification.id: DateTime.now().toUtc()});
    try {
      await _notificationsRepository.markRead(notification.id);
    } on ApiException {
      // It is marked the next time it is opened.
    }
  }

  /// Marks everything read.
  Future<void> readAll() async {
    if (!state.hasUnread) return;
    final before = state.notifications;
    final now = DateTime.now().toUtc();
    _show({
      for (final one in before)
        if (!one.isRead) one.id: now,
    });
    try {
      await _notificationsRepository.markAllRead();
    } on ApiException catch (error) {
      if (!isClosed) emit(_with(notifications: before, error: error));
    }
  }

  void _show(Map<String, DateTime> readAt) {
    emit(
      _with(
        notifications: [
          for (final one in state.notifications)
            if (readAt.containsKey(one.id))
              AppNotification(
                id: one.id,
                type: one.type,
                title: one.title,
                body: one.body,
                createdAt: one.createdAt,
                data: one.data,
                organizationId: one.organizationId,
                readAt: readAt[one.id],
              )
            else
              one,
        ],
      ),
    );
  }

  NotificationsState _with({
    List<AppNotification>? notifications,
    String? Function()? next,
    bool loadingMore = false,
    ApiException? error,
  }) {
    return NotificationsState(
      status: state.status,
      notifications: notifications ?? state.notifications,
      next: next == null ? state.next : next(),
      loadingMore: loadingMore,
      error: error,
    );
  }
}
