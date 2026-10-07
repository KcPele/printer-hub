import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

enum SubmitStatus { idle, inProgress, success, failure }

/// Where a form's submission stands.
class SubmitState extends Equatable {
  const new({this.status = SubmitStatus.idle, this.error});

  final SubmitStatus status;

  /// Why the last attempt failed. Pass it to `errorMessage`.
  final ApiException? error;

  bool get inProgress => status == SubmitStatus.inProgress;
  bool get succeeded => status == SubmitStatus.success;
  bool get failed => status == SubmitStatus.failure;

  @override
  List<Object?> get props => [status, error];
}

/// The shared shape of a form that sends one request.
abstract class SubmitCubit extends Cubit<SubmitState> {
  new() : super(const SubmitState());

  /// Runs [action] once: a second submission while one is in progress is
  /// ignored.
  @protected
  Future<void> run(Future<void> Function() action) async {
    if (state.inProgress) return;
    emit(const SubmitState(status: SubmitStatus.inProgress));
    try {
      await action();
      emit(const SubmitState(status: SubmitStatus.success));
    } on ApiException catch (error) {
      emit(SubmitState(status: SubmitStatus.failure, error: error));
    }
  }
}
