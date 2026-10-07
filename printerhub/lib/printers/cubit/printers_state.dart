part of 'printers_cubit.dart';

enum PrintersStatus { initial, loading, ready, failure }

class PrintersState extends Equatable {
  const new({
    this.status = PrintersStatus.initial,
    this.printers = const [],
    this.live = const {},
    this.checking = const {},
    this.error,
  });

  final PrintersStatus status;

  /// The workspace's printers, as the backend lists them.
  final List<PrinterRead> printers;

  /// What each printer said when this device last asked it, by printer id.
  /// Fresher than the backend's record, and known when offline.
  final Map<String, DeviceStatus> live;

  /// The printers being asked right now.
  final Set<String> checking;

  /// Why the list could not be loaded. Pass it to `errorMessage`.
  final ApiException? error;

  PrinterRead? printer(String id) {
    return printers.where((printer) => printer.id == id).firstOrNull;
  }

  PrintersState copyWith({
    PrintersStatus? status,
    List<PrinterRead>? printers,
    Map<String, DeviceStatus>? live,
    Set<String>? checking,
    ApiException? error,
  }) {
    return PrintersState(
      status: status ?? this.status,
      printers: printers ?? this.printers,
      live: live ?? this.live,
      checking: checking ?? this.checking,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, printers, live, checking, error];
}
