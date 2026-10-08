import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printers_repository/printers_repository.dart';

enum RecheckStatus { idle, asking, done, noAnswer, refused }

class RecheckState extends Equatable {
  const new([this.status = RecheckStatus.idle, this.error]);

  final RecheckStatus status;

  /// Why the backend refused. Pass it to `errorMessage`.
  final ApiException? error;

  bool get asking => status == RecheckStatus.asking;

  @override
  List<Object?> get props => [status, error];
}

/// Asks a printer again what it can do: for when a finisher was fitted, or
/// scanning was switched on, after the printer was added.
class RecheckPrinterCubit extends Cubit<RecheckState> {
  new({required this._printersCubit}) : super(const RecheckState());

  final PrintersCubit _printersCubit;

  Future<void> recheck(PrinterRead printer) async {
    if (state.asking) return;
    emit(const RecheckState(RecheckStatus.asking));
    try {
      await _printersCubit.recheck(printer);
      emit(const RecheckState(RecheckStatus.done));
    } on ProbeFailure {
      emit(const RecheckState(RecheckStatus.noAnswer));
    } on ApiException catch (error) {
      emit(RecheckState(RecheckStatus.refused, error));
    }
  }
}
