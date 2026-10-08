import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printer_discovery/printer_discovery.dart';
import 'package:printerhub/printers/finders.dart';
import 'package:printers_repository/printers_repository.dart';

enum AddPrinterStep {
  /// Choosing how to connect, with nearby printers listed.
  ways,

  /// Typing an address.
  address,

  /// Pointing the camera at a code.
  qr,

  /// Following the steps to join the printer's own Wi-Fi.
  wifiDirect,

  /// Looking at which printers are near over Bluetooth.
  bluetooth,

  /// Asking a device what it is, or redeeming a pairing code.
  searching,

  /// The device answered. Waiting for a name.
  found,

  /// Saving the printer to the workspace.
  saving,

  /// The printer is in the workspace.
  added,

  /// A pairing code named a printer that is already in a workspace.
  paired,
}

/// Something to tell the user that is not a failed search or an API error.
enum AddPrinterNotice {
  codeNotRecognised,
  nfcNothing,
  nfcFailed,
  notOnPrinterNetwork,
  seenButNotOnNetwork,
}

class AddPrinterState extends Equatable {
  const new({
    this.step = AddPrinterStep.ways,
    this.address = '',
    this.device,
    this.printer,
    this.probeFailure,
    this.error,
    this.notice,
    this.noticeSubject,
    this.wifi,
    this.readingNfc = false,
    this.nfcAvailable = false,
    this.bluetoothAvailable = false,
  });

  final AddPrinterStep step;

  /// The address last looked at, so it is still there to correct when
  /// nothing was found.
  final String address;

  /// What the device said about itself, from [AddPrinterStep.found] on.
  final DeviceDescription? device;

  /// The saved or paired printer.
  final PrinterRead? printer;

  /// Why no printer was found where it was looked for.
  final ProbeFailureKind? probeFailure;

  /// Why the API refused. Pass it to `errorMessage`.
  final ApiException? error;
  final AddPrinterNotice? notice;

  /// The name the [notice] is about, when it is about a device.
  final String? noticeSubject;

  /// The printer's own Wi-Fi network, when a code or tag named it.
  final WifiNetworkCode? wifi;

  /// True while waiting for the phone to be tapped against a tag.
  final bool readingNfc;
  final bool nfcAvailable;
  final bool bluetoothAvailable;

  /// The same state on another [step], with every message cleared: a
  /// message belongs to the attempt that caused it.
  AddPrinterState on(
    AddPrinterStep step, {
    String? address,
    DeviceDescription? device,
    PrinterRead? printer,
    ProbeFailureKind? probeFailure,
    ApiException? error,
    AddPrinterNotice? notice,
    String? noticeSubject,
    WifiNetworkCode? wifi,
    bool readingNfc = false,
  }) {
    return AddPrinterState(
      step: step,
      address: address ?? this.address,
      device: device ?? this.device,
      printer: printer,
      probeFailure: probeFailure,
      error: error,
      notice: notice,
      noticeSubject: noticeSubject,
      wifi: wifi ?? this.wifi,
      readingNfc: readingNfc,
      nfcAvailable: nfcAvailable,
      bluetoothAvailable: bluetoothAvailable,
    );
  }

  @override
  List<Object?> get props => [
    step,
    address,
    device,
    printer,
    probeFailure,
    error,
    notice,
    noticeSubject,
    wifi,
    readingNfc,
    nfcAvailable,
    bluetoothAvailable,
  ];
}

/// Walks through adding a printer: find it one way or another, name it,
/// save it.
///
/// Every way of finding a printer ends in the same place. A printer found
/// on the network, at an address, on its own Wi-Fi, or next to the phone is
/// asked what it is and then named. A pairing code names a printer that is
/// already saved, which is simply opened.
class AddPrinterCubit extends Cubit<AddPrinterState> {
  new({
    required this._printersRepository,
    required this._finders,
    required this._organizationId,
  }) : super(const AddPrinterState());

  final PrintersRepository _printersRepository;
  final PrinterFinders _finders;
  final String _organizationId;

  bool get _busy =>
      state.step == AddPrinterStep.searching ||
      state.step == AddPrinterStep.saving;

  /// Finds out which radios this phone can use. Call once.
  Future<void> start() async {
    final nfc = await _finders.nfc.isAvailable;
    final bluetooth = await _finders.bluetooth.isAvailable;
    emit(
      AddPrinterState(
        step: state.step,
        address: state.address,
        nfcAvailable: nfc,
        bluetoothAvailable: bluetooth,
      ),
    );
  }

  /// Opens one of the ways to connect that has a screen of its own.
  void choose(AddPrinterStep way) => emit(state.on(way));

  /// Returns to the list of ways to connect.
  void back() => emit(state.on(AddPrinterStep.ways));

  /// Asks the device at [address] what it is.
  Future<void> find(String address) {
    return _ask(
      () => _printersRepository.probe(address),
      from: AddPrinterStep.address,
      address: address,
    );
  }

  /// Asks a printer that announced itself on the network what it is.
  Future<void> findNearby(NearbyDevice device) {
    return _ask(
      () => _printersRepository.probeAnnounced(
        host: device.host,
        ipp: device.ipp,
        escl: device.escl,
      ),
      from: state.step,
    );
  }

  /// Looks for the printer on the Wi-Fi the phone has joined. On a
  /// printer's own network (Wi-Fi Direct) the printer runs the network, so
  /// it is at the gateway address.
  Future<void> findOnThisNetwork() async {
    if (_busy) return;
    final gateway = await _finders.wifi.gatewayAddress();
    if (gateway == null) {
      emit(
        state.on(
          AddPrinterStep.wifiDirect,
          notice: AddPrinterNotice.notOnPrinterNetwork,
        ),
      );
      return;
    }
    await _ask(
      () => _printersRepository.probe(gateway),
      from: AddPrinterStep.wifiDirect,
    );
  }

  /// Picks a printer seen over Bluetooth. Bluetooth says which printer is
  /// near, not how to reach it, so it is matched to one of the printers
  /// [onNetwork] and reached over Wi-Fi.
  Future<void> pickSighting(
    BluetoothSighting sighting,
    List<NearbyDevice> onNetwork,
  ) async {
    final match = matchSighting(sighting, onNetwork);
    if (match == null) {
      emit(
        state.on(
          AddPrinterStep.bluetooth,
          notice: AddPrinterNotice.seenButNotOnNetwork,
          noticeSubject: sighting.name,
        ),
      );
      return;
    }
    await findNearby(match);
  }

  /// Waits for the phone to be tapped against the printer, then acts on
  /// what its tag holds.
  Future<void> readNfc() async {
    if (_busy || state.readingNfc) return;
    emit(state.on(AddPrinterStep.ways, readingNfc: true));
    try {
      final text = await _finders.nfc.read();
      if (!state.readingNfc) return;
      if (text == null) {
        emit(
          state.on(AddPrinterStep.ways, notice: AddPrinterNotice.nfcNothing),
        );
      } else {
        await useCode(text, from: AddPrinterStep.ways);
      }
    } on Object {
      if (!state.readingNfc) return;
      emit(state.on(AddPrinterStep.ways, notice: AddPrinterNotice.nfcFailed));
    }
  }

  /// Stops waiting for a tag.
  Future<void> cancelNfc() async {
    if (!state.readingNfc) return;
    emit(state.on(AddPrinterStep.ways));
    await _finders.nfc.cancel();
  }

  /// Acts on the text of a scanned QR code or a tapped tag.
  Future<void> useCode(String raw, {AddPrinterStep? from}) async {
    if (_busy) return;
    final origin = from ?? state.step;

    switch (ScannedCode.parse(raw)) {
      case PairingCode(:final token):
        emit(state.on(AddPrinterStep.searching));
        try {
          final printer = await _printersRepository.redeemPairingCode(token);
          emit(state.on(AddPrinterStep.paired, printer: printer));
        } on ApiException catch (error) {
          emit(state.on(origin, error: error));
        }
      case PrinterAddressCode(:final address):
        await _ask(
          () => _printersRepository.probe(address),
          from: origin,
          address: address,
        );
      case final WifiNetworkCode network:
        emit(state.on(AddPrinterStep.wifiDirect, wifi: network));
      case UnrecognisedCode():
        emit(state.on(origin, notice: AddPrinterNotice.codeNotRecognised));
    }
  }

  /// Saves the found device to the workspace as [name].
  Future<void> save({required String name, String? location}) async {
    final device = state.device;
    if (device == null || _busy) return;

    emit(state.on(AddPrinterStep.saving));
    try {
      final printer = await _printersRepository.add(
        organizationId: _organizationId,
        device: device,
        name: name,
        location: location,
      );
      emit(state.on(AddPrinterStep.added, printer: printer));
    } on ApiException catch (error) {
      emit(state.on(AddPrinterStep.found, error: error));
    }
  }

  /// Asks a device what it is. When it does not answer, returns to the
  /// step the question came [from], with the reason.
  Future<void> _ask(
    Future<DeviceDescription> Function() ask, {
    required AddPrinterStep from,
    String? address,
  }) async {
    if (_busy) return;
    emit(state.on(AddPrinterStep.searching, address: address));
    try {
      final device = await ask();
      emit(state.on(AddPrinterStep.found, device: device));
    } on ProbeFailure catch (failure) {
      emit(state.on(from, probeFailure: failure.kind));
    }
  }
}
