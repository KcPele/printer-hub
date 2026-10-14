import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:printerhub/documents/document_sources.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/tools/cubit/make_cubit.dart';
import 'package:printerhub/tools/pdf_lock.dart';

/// Which PDF, and the password it is to open with, typed twice.
class LockChoices extends Equatable {
  const new({this.document, this.password = '', this.again = ''});

  /// The PDF chosen, or null before one is.
  final PickedDocument? document;
  final String password;

  /// The password typed a second time, so a slip is caught before the
  /// PDF is locked with it.
  final String again;

  /// The fewest letters a password may have.
  static const int shortest = 4;

  /// True when the password is long enough.
  bool get long => password.length >= shortest;

  /// True when it was typed the same both times.
  bool get matches => password == again;

  LockChoices copyWith({
    PickedDocument? document,
    String? password,
    String? again,
  }) {
    return LockChoices(
      document: document ?? this.document,
      password: password ?? this.password,
      again: again ?? this.again,
    );
  }

  @override
  List<Object?> get props => [document, password, again];
}

/// Puts a password on a PDF: every reader asks for it before it shows a
/// page. The password is not kept anywhere: only the person knows it.
///
/// Each page is drawn as a picture first, as the other tools that change
/// a PDF do, so the words in the result can no longer be picked out.
class LockCubit extends MakeCubit<LockChoices> {
  new({
    required super.sharer,
    required super.keep,
    required super.name,
    required this._picker,
    required this._renderer,
    super.directory,
  }) : super(choices: const LockChoices());

  final DocumentPicker _picker;
  final PageRenderer _renderer;
  bool _choosing = false;

  /// Asks for a PDF.
  Future<void> choose() async {
    if (_choosing || state.working) return;
    _choosing = true;
    try {
      final document = await _picker.pickPdf();
      if (document == null || isClosed) return;
      change(state.choices.copyWith(document: document));
    } finally {
      _choosing = false;
    }
  }

  /// Takes a PDF that is already open, with nothing to choose.
  void use(PickedDocument document) {
    change(state.choices.copyWith(document: document));
  }

  @override
  String get source => DocumentSources.lockedPdf;

  @override
  bool ready(LockChoices choices) =>
      choices.document != null && choices.long && choices.matches;

  @override
  Future<File> build(LockChoices choices) async {
    final pages = <Uint8List>[];
    await _renderer.pictures(choices.document!).forEach(pages.add);
    return await lockedPdf(
      pages: pages,
      password: choices.password,
      name: name,
      directory: directory,
    );
  }
}
