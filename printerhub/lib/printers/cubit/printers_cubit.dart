import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printers_repository/printers_repository.dart';

part 'printers_state.dart';

/// The printers of the workspace in use, and what each one is doing.
///
/// It follows the workspace: switching workspace loads that one's printers,
/// and signing out empties the list.
class PrintersCubit extends Cubit<PrintersState> {
  new({
    required this._printersRepository,
    required Stream<String?> organizationChanges,
    this._organizationId,
  }) : super(const PrintersState()) {
    _organizations = organizationChanges.listen(_onOrganization);
  }

  final PrintersRepository _printersRepository;
  late final StreamSubscription<String?> _organizations;
  String? _organizationId;

  /// Fetches the list, then asks each printer what it is doing.
  Future<void> load() async {
    final organizationId = _organizationId;
    if (organizationId == null) return;

    emit(state.copyWith(status: PrintersStatus.loading));
    try {
      final printers = await _printersRepository.list(organizationId);
      if (organizationId != _organizationId) return;
      emit(state.copyWith(status: PrintersStatus.ready, printers: printers));
      await Future.wait(printers.map(checkStatus));
    } on ApiException catch (error) {
      if (organizationId != _organizationId) return;
      emit(state.copyWith(status: PrintersStatus.failure, error: error));
    }
  }

  /// Asks [printer] itself what it is doing, over the local network.
  Future<void> checkStatus(PrinterRead printer) async {
    final organizationId = _organizationId;
    if (organizationId == null || state.checking.contains(printer.id)) return;

    emit(state.copyWith(checking: {...state.checking, printer.id}));
    final result = await _printersRepository.refreshStatus(
      organizationId: organizationId,
      printer: printer,
    );
    if (organizationId != _organizationId) return;
    emit(
      state.copyWith(
        printers: [
          for (final existing in state.printers)
            if (existing.id == printer.id) result.printer else existing,
        ],
        live: {...state.live, printer.id: result.status},
        checking: {...state.checking}..remove(printer.id),
      ),
    );
  }

  /// Puts a newer record of a printer in the list.
  void updated(PrinterRead printer) {
    emit(
      state.copyWith(
        printers: [
          for (final existing in state.printers)
            if (existing.id == printer.id) printer else existing,
        ],
      ),
    );
  }

  /// Reads one printer again from the backend, after something about it
  /// was changed there. A failure leaves the list as it is.
  Future<void> refresh(String printerId) async {
    final organizationId = _organizationId;
    if (organizationId == null) return;
    try {
      final printer = await _printersRepository.get(
        organizationId: organizationId,
        printerId: printerId,
      );
      if (organizationId == _organizationId) updated(printer);
    } on ApiException {
      // The next load brings it up to date.
    }
  }

  /// Asks [printer] again what it can do, and records the answer.
  ///
  /// Throws a [ProbeFailure] when it does not answer and an [ApiException]
  /// when the backend refuses.
  Future<void> recheck(PrinterRead printer) async {
    updated(
      await _printersRepository.recheck(
        organizationId: _organizationId!,
        printer: printer,
      ),
    );
  }

  /// Puts a printer that was just added in the list, without a reload.
  void added(PrinterRead printer, DeviceStatus status) {
    emit(
      state.copyWith(
        status: PrintersStatus.ready,
        printers: [...state.printers, printer],
        live: {...state.live, printer.id: status},
      ),
    );
  }

  /// Removes a printer from the workspace. Throws an [ApiException] when
  /// the backend refuses.
  Future<void> remove(String printerId) async {
    await _printersRepository.remove(
      organizationId: _organizationId!,
      printerId: printerId,
    );
    emit(
      state.copyWith(
        printers: [
          for (final printer in state.printers)
            if (printer.id != printerId) printer,
        ],
        live: {...state.live}..remove(printerId),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _organizations.cancel();
    await super.close();
  }

  Future<void> _onOrganization(String? organizationId) async {
    if (organizationId == _organizationId) return;
    _organizationId = organizationId;
    emit(const PrintersState());
    await load();
  }
}
