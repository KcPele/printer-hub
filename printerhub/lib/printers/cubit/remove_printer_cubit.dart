import 'package:printerhub/auth/cubit/submit_cubit.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';

class RemovePrinterCubit extends SubmitCubit {
  new({required this._printersCubit});

  final PrintersCubit _printersCubit;

  Future<void> submit({required String printerId}) {
    return run(() => _printersCubit.remove(printerId));
  }
}
