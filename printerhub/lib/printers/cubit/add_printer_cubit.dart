import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printers_repository/printers_repository.dart';

enum AddPrinterStep {
  /// Waiting for an address.
  address,

  /// Asking the device what it is.
  searching,

  /// The device answered. Waiting for a name.
  found,

  /// Saving the printer to the workspace.
  saving,

  /// The printer is in the workspace.
  added,
}

class AddPrinterState extends Equatable {
  const new({
    this.step = AddPrinterStep.address,
    this.address = '',
    this.device,
    this.printer,
    this.probeFailure,
    this.error,
  });

  final AddPrinterStep step;

  /// The address last looked at, so it is still there to correct when
  /// nothing was found.
  final String address;

  /// What the device said about itself, from [AddPrinterStep.found] on.
  final DeviceDescription? device;

  /// The saved printer, at [AddPrinterStep.added].
  final PrinterRead? printer;

  /// Why no printer was found at the address.
  final ProbeFailureKind? probeFailure;

  /// Why the printer could not be saved. Pass it to `errorMessage`.
  final ApiException? error;

  @override
  List<Object?> get props => [
    step,
    address,
    device,
    printer,
    probeFailure,
    error,
  ];
}

/// Walks through adding a printer: find it by address, name it, save it.
class AddPrinterCubit extends Cubit<AddPrinterState> {
  new({required this._printersRepository, required this._organizationId})
    : super(const AddPrinterState());

  final PrintersRepository _printersRepository;
  final String _organizationId;

  /// Asks the device at [address] what it is.
  Future<void> find(String address) async {
    if (state.step == AddPrinterStep.searching) return;
    emit(AddPrinterState(step: AddPrinterStep.searching, address: address));
    try {
      final device = await _printersRepository.probe(address);
      emit(
        AddPrinterState(
          step: AddPrinterStep.found,
          address: address,
          device: device,
        ),
      );
    } on ProbeFailure catch (failure) {
      emit(AddPrinterState(address: address, probeFailure: failure.kind));
    }
  }

  /// Returns to the address, to try another one.
  void startOver() => emit(AddPrinterState(address: state.address));

  /// Saves the found device to the workspace as [name].
  Future<void> save({required String name, String? location}) async {
    final device = state.device;
    if (device == null || state.step == AddPrinterStep.saving) return;

    emit(
      AddPrinterState(
        step: AddPrinterStep.saving,
        address: state.address,
        device: device,
      ),
    );
    try {
      final printer = await _printersRepository.add(
        organizationId: _organizationId,
        device: device,
        name: name,
        location: location,
      );
      emit(
        AddPrinterState(
          step: AddPrinterStep.added,
          address: state.address,
          device: device,
          printer: printer,
        ),
      );
    } on ApiException catch (error) {
      emit(
        AddPrinterState(
          step: AddPrinterStep.found,
          address: state.address,
          device: device,
          error: error,
        ),
      );
    }
  }
}
