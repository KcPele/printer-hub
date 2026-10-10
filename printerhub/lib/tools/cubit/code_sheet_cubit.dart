import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/cubit/make_cubit.dart';
import 'package:printerhub/tools/made_pages.dart';
import 'package:printerhub/tools/pdf_font.dart';

/// What a sign with a code on it is to say.
class CodeSheetChoices extends Equatable {
  const new({
    this.wifi = false,
    this.text = '',
    this.network = '',
    this.password = '',
    this.title = '',
    this.paper = ScanPaper.a4,
  });

  /// True for a code that joins a Wi-Fi network, false for a link or any
  /// words.
  final bool wifi;

  /// The link or words the code says.
  final String text;

  /// The Wi-Fi network's name and password.
  final String network;
  final String password;

  /// Words set large above the code.
  final String title;
  final ScanPaper paper;

  CodeSheetChoices copyWith({
    bool? wifi,
    String? text,
    String? network,
    String? password,
    String? title,
    ScanPaper? paper,
  }) {
    return CodeSheetChoices(
      wifi: wifi ?? this.wifi,
      text: text ?? this.text,
      network: network ?? this.network,
      password: password ?? this.password,
      title: title ?? this.title,
      paper: paper ?? this.paper,
    );
  }

  @override
  List<Object?> get props => [wifi, text, network, password, title, paper.name];
}

/// Makes a sign to print with a QR code on it: a link, some words, or a
/// Wi-Fi network to join.
class CodeSheetCubit extends MakeCubit<CodeSheetChoices> {
  new({
    required super.sharer,
    required super.keep,
    required super.name,
    this._font = pdfFont,
    super.directory,
  }) : super(choices: const CodeSheetChoices());

  final PdfFontLoader _font;

  /// The longest words a code is asked to carry: past this it is too
  /// fine to read off paper.
  static const int maxLength = 500;

  @override
  bool ready(CodeSheetChoices choices) => choices.wifi
      ? choices.network.trim().isNotEmpty
      : choices.text.trim().isNotEmpty;

  @override
  Future<File> build(CodeSheetChoices choices) async {
    final text = choices.text.trim();
    return await codeSheet(
      data: choices.wifi
          ? wifiCode(
              network: choices.network.trim(),
              password: choices.password,
            )
          : text,
      title: choices.title,
      // What the code says, where that is short enough to read: never a
      // Wi-Fi password.
      caption: choices.wifi
          ? choices.network.trim()
          : text.length <= 80
          ? text
          : '',
      paper: choices.paper,
      name: name,
      directory: directory,
      font: await _font(),
    );
  }
}
