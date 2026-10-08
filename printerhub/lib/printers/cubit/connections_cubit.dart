import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/printers/cubit/printers_cubit.dart';
import 'package:printers_repository/printers_repository.dart';

enum ConnectionsStatus { loading, ready, failed }

/// What the last change did, when it is worth saying.
enum ConnectionsNotice { added, nothingNew, passwordChanged }

class ConnectionsState extends Equatable {
  const new({
    this.status = ConnectionsStatus.loading,
    this.connections = const [],
    this.busy = false,
    this.error,
    this.probeFailure,
    this.notice,
  });

  final ConnectionsStatus status;

  /// The printer's connections, the one tried first at the top.
  final List<ConnectionRead> connections;

  /// True while a change is being made.
  final bool busy;

  /// Why the API refused. Pass it to `errorMessage`.
  final ApiException? error;

  /// Why no printer was found at an address that was typed.
  final ProbeFailureKind? probeFailure;
  final ConnectionsNotice? notice;

  @override
  List<Object?> get props => [
    status,
    connections,
    busy,
    error,
    probeFailure,
    notice,
  ];
}

/// The ways one printer is reached: their order, and adding, removing, and
/// re-keying them.
class ConnectionsCubit extends Cubit<ConnectionsState> {
  new({
    required this._printersRepository,
    required this._printersCubit,
    required this._organizationId,
    required this._printerId,
  }) : super(const ConnectionsState());

  final PrintersRepository _printersRepository;
  final PrintersCubit _printersCubit;
  final String _organizationId;
  final String _printerId;

  PrinterRead? get _printer => _printersCubit.state.printer(_printerId);

  Future<void> load() async {
    emit(const ConnectionsState());
    try {
      emit(_ready(await _read()));
    } on ApiException catch (error) {
      emit(ConnectionsState(status: ConnectionsStatus.failed, error: error));
    }
  }

  /// Makes [connection] the one tried first.
  Future<void> preferFirst(ConnectionRead connection) {
    return _change(() async {
      final ordered = await _printersRepository.setConnectionOrder(
        organizationId: _organizationId,
        printerId: _printerId,
        connectionIds: [
          connection.id,
          for (final other in state.connections)
            if (other.id != connection.id) other.id,
        ],
      );
      return _ready(ordered);
    });
  }

  Future<void> remove(ConnectionRead connection) {
    return _change(() async {
      await _printersRepository.removeConnection(
        organizationId: _organizationId,
        printerId: _printerId,
        connectionId: connection.id,
      );
      return _ready(await _read());
    });
  }

  /// Looks for the printer at [address] and saves the ways it answers
  /// there that are not saved yet.
  Future<void> addAddress(String address) {
    return _change(() async {
      final printer = _printer!;
      final credentials = await _printersRepository.credentialsFor(
        organizationId: _organizationId,
        printer: printer,
      );
      final device = await _printersRepository.probe(
        address,
        credentials: credentials,
      );
      final added = await _printersRepository.addConnections(
        organizationId: _organizationId,
        printer: printer,
        device: device,
        credentials: credentials,
      );
      return _ready(
        await _read(),
        notice: added == 0
            ? ConnectionsNotice.nothingNew
            : ConnectionsNotice.added,
      );
    });
  }

  /// Replaces the user name and password kept with [connection].
  Future<void> setPassword(
    ConnectionRead connection, {
    required String userName,
    required String password,
  }) {
    return _change(() async {
      await _printersRepository.setCredentials(
        organizationId: _organizationId,
        connection: connection,
        credentials: PrinterCredentials(userName: userName, password: password),
      );
      return _ready(await _read(), notice: ConnectionsNotice.passwordChanged);
    });
  }

  Future<List<ConnectionRead>> _read() {
    return _printersRepository.connections(
      organizationId: _organizationId,
      printerId: _printerId,
    );
  }

  ConnectionsState _ready(
    List<ConnectionRead> connections, {
    ConnectionsNotice? notice,
  }) {
    return ConnectionsState(
      status: ConnectionsStatus.ready,
      connections: connections,
      notice: notice,
    );
  }

  /// Makes one change at a time. When it fails the list stays as it was,
  /// with the reason. When it works the printer's record is read again, so
  /// every other screen sees the change.
  Future<void> _change(Future<ConnectionsState> Function() change) async {
    if (state.busy || state.status != ConnectionsStatus.ready) return;
    final before = state.connections;
    emit(
      ConnectionsState(
        status: ConnectionsStatus.ready,
        connections: before,
        busy: true,
      ),
    );
    try {
      emit(await change());
      await _printersCubit.refresh(_printerId);
    } on ProbeFailure catch (failure) {
      emit(
        ConnectionsState(
          status: ConnectionsStatus.ready,
          connections: before,
          probeFailure: failure.kind,
        ),
      );
    } on ApiException catch (error) {
      emit(
        ConnectionsState(
          status: ConnectionsStatus.ready,
          connections: before,
          error: error,
        ),
      );
    }
  }
}
