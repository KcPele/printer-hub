import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:organizations_repository/organizations_repository.dart';

enum LogStatus { loading, ready, failed }

class LogState extends Equatable {
  const new({
    this.status = LogStatus.loading,
    this.actions = const [],
    this.next,
    this.loadingMore = false,
    this.error,
  });

  final LogStatus status;

  /// What was done in the workspace, newest first, as far as read.
  final List<LoggedAction> actions;

  /// Where the next page starts. Null when there is no more.
  final String? next;
  final bool loadingMore;

  /// Why the log could not be read. Pass it to `errorMessage`.
  final ApiException? error;

  @override
  List<Object?> get props => [status, actions, next, loadingMore, error];
}

/// What was done in a workspace, and by whom.
class LogCubit extends Cubit<LogState> {
  new({required this._organizationsRepository, required this._organizationId})
    : super(const LogState());

  final OrganizationsRepository _organizationsRepository;
  final String _organizationId;

  Future<void> load() async {
    emit(const LogState());
    try {
      final page = await _organizationsRepository.log(_organizationId);
      if (isClosed) return;
      emit(
        LogState(
          status: LogStatus.ready,
          actions: page.actions,
          next: page.next,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(LogState(status: LogStatus.failed, error: error));
    }
  }

  /// Reads the next page.
  Future<void> more() async {
    final cursor = state.next;
    if (cursor == null || state.loadingMore) return;
    emit(
      LogState(
        status: LogStatus.ready,
        actions: state.actions,
        next: cursor,
        loadingMore: true,
      ),
    );
    try {
      final page = await _organizationsRepository.log(
        _organizationId,
        cursor: cursor,
      );
      if (isClosed) return;
      emit(
        LogState(
          status: LogStatus.ready,
          actions: [...state.actions, ...page.actions],
          next: page.next,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(
        LogState(
          status: LogStatus.ready,
          actions: state.actions,
          next: cursor,
          error: error,
        ),
      );
    }
  }
}
