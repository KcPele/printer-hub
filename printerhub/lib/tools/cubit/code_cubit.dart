import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/tools/code.dart';

class CodeState extends Equatable {
  const new({this.code, this.unopened = false});

  /// The code that was read, or null while the camera is looking.
  final ReadCode? code;

  /// True when nothing on the phone would open the code's link.
  final bool unopened;

  @override
  List<Object?> get props => [code, unopened];
}

/// Reads a QR code or barcode with the camera and says what it holds.
class CodeCubit extends Cubit<CodeState> {
  new({required this._links}) : super(const CodeState());

  final LinkOpener _links;

  /// Takes what the camera read. The first code is kept: the camera goes
  /// on seeing it many times a second.
  void found(String text) {
    if (state.code != null || text.trim().isEmpty) return;
    emit(CodeState(code: ReadCode.read(text)));
  }

  /// Opens the code's link in the phone's browser.
  Future<void> open() async {
    final code = state.code;
    final link = code?.link;
    if (link == null) return;
    final opened = await _links.open(link);
    if (!isClosed) emit(CodeState(code: code, unopened: !opened));
  }

  /// Goes back to the camera for another code.
  void again() => emit(const CodeState());
}
