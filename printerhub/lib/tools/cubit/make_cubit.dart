import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/scan/scan_output.dart';

/// Where a tool that makes a document has got to: what was asked for,
/// and the PDF once it is made.
class MakeState<C> extends Equatable {
  const new({
    required this.choices,
    this.working = false,
    this.file,
    this.failure,
  });

  /// What the document is to be.
  final C choices;

  /// True while the document is being made.
  final bool working;

  /// The document, once it is made: a PDF to print or share.
  final File? file;

  /// Why it could not be made: a code such as `tools.unreadable`. Pass it
  /// to `ToolWords.failure`.
  final String? failure;

  @override
  List<Object?> get props => [choices, working, file?.path, failure];
}

/// A tool that makes a PDF out of what the person asks for, to print or
/// share: a sign with a code on it, a note, a ruled page. A tool says
/// what it makes in [build], and when it has enough to make it in
/// [ready].
abstract class MakeCubit<C> extends Cubit<MakeState<C>> {
  new({
    required C choices,
    required this._sharer,
    required this.name,
    Directory? directory,
  }) : directory = directory ?? Directory.systemTemp,
       super(MakeState(choices: choices));

  final ScanSharer _sharer;

  /// What the document is called.
  final String name;

  /// Where the document is written.
  final Directory directory;

  /// True when [choices] say enough to make the document.
  bool ready(C choices) => true;

  /// Makes the document.
  Future<File> build(C choices);

  /// Changes what is asked for. A document already made is no longer
  /// that, and is dropped.
  void change(C choices) {
    if (!state.working) emit(MakeState(choices: choices));
  }

  /// Makes the document.
  Future<void> make() async {
    final choices = state.choices;
    if (state.working || !ready(choices)) return;
    emit(MakeState(choices: choices, working: true));
    try {
      final file = await build(choices);
      if (!isClosed) emit(MakeState(choices: choices, file: file));
    } on Object {
      if (!isClosed) {
        emit(MakeState(choices: choices, failure: 'tools.unreadable'));
      }
    }
  }

  /// Hands the document to the phone's share sheet.
  Future<void> share() async {
    final file = state.file;
    if (file != null) await _sharer.share([file], name: name);
  }
}
