import 'package:api_client/api_client.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

enum DevicesStatus { loading, ready, failed }

class DevicesState extends Equatable {
  const new({
    this.status = DevicesStatus.loading,
    this.sessions = const [],
    this.devices = const [],
    this.error,
    this.busyId,
  });

  final DevicesStatus status;

  /// Where the account is signed in, this device first.
  final List<UserSession> sessions;

  /// The phones the account has been used on, this one first.
  final List<UserDevice> devices;

  /// Why the list could not be read, or the last change could not be made.
  /// Pass it to `errorMessage`.
  final ApiException? error;

  /// The session or device being signed out or forgotten.
  final String? busyId;

  /// The device a session is on, when it registered one.
  UserDevice? deviceOf(UserSession session) {
    return devices.where((device) => device.id == session.deviceId).firstOrNull;
  }

  @override
  List<Object?> get props => [status, sessions, devices, error, busyId];
}

/// Where the account is signed in and which phones it knows, with the means
/// to sign another one out or forget it.
class DevicesCubit extends Cubit<DevicesState> {
  new({required this._authRepository}) : super(const DevicesState());

  final AuthRepository _authRepository;

  Future<void> load() async {
    emit(const DevicesState());
    try {
      final sessions = await _authRepository.sessions();
      final devices = await _authRepository.devices();
      emit(
        DevicesState(
          status: DevicesStatus.ready,
          sessions: [
            ...sessions.where((session) => session.isCurrent),
            ...sessions.where((session) => !session.isCurrent),
          ],
          devices: [
            ...devices.where((device) => device.isThisDevice),
            ...devices.where((device) => !device.isThisDevice),
          ],
        ),
      );
    } on ApiException catch (error) {
      emit(DevicesState(status: DevicesStatus.failed, error: error));
    }
  }

  /// Signs another device out.
  Future<void> signOut(UserSession session) {
    return _change(session.id, () async {
      await _authRepository.revokeSession(session.id);
      return DevicesState(
        status: DevicesStatus.ready,
        sessions: [
          for (final item in state.sessions)
            if (item.id != session.id) item,
        ],
        devices: state.devices,
      );
    });
  }

  /// Forgets a device, which stops its notifications.
  Future<void> forget(UserDevice device) {
    return _change(device.id, () async {
      await _authRepository.removeDevice(device.id);
      return DevicesState(
        status: DevicesStatus.ready,
        sessions: state.sessions,
        devices: [
          for (final item in state.devices)
            if (item.id != device.id) item,
        ],
      );
    });
  }

  Future<void> _change(
    String id,
    Future<DevicesState> Function() change,
  ) async {
    if (state.busyId != null) return;
    emit(
      DevicesState(
        status: DevicesStatus.ready,
        sessions: state.sessions,
        devices: state.devices,
        busyId: id,
      ),
    );
    try {
      emit(await change());
    } on ApiException catch (error) {
      emit(
        DevicesState(
          status: DevicesStatus.ready,
          sessions: state.sessions,
          devices: state.devices,
          error: error,
        ),
      );
    }
  }
}
