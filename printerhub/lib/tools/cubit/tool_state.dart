import 'dart:io';

import 'package:equatable/equatable.dart';

enum ToolStatus {
  /// Nothing chosen yet.
  idle,

  /// Reading the file and making the result.
  working,

  /// The result is ready.
  done,
}

/// Where a tool has got to: a file is chosen, worked on, and something
/// comes out of it, words or files.
class ToolState extends Equatable {
  const new({
    this.status = ToolStatus.idle,
    this.name = '',
    this.text = '',
    this.files = const [],
    this.failure,
  });

  final ToolStatus status;

  /// The name of the file chosen, without its ending.
  final String name;

  /// The words found, for a tool that reads.
  final String text;

  /// The files made, for a tool that makes files.
  final List<File> files;

  /// Why the last file chosen came to nothing: a code such as
  /// `tools.unreadable`. Pass it to `ToolWords.failure`.
  final String? failure;

  @override
  List<Object?> get props => [
    status,
    name,
    text,
    [for (final file in files) file.path],
    failure,
  ];
}

/// [name] without its ending: `Report.pdf` is `Report`.
String nameWithoutEnding(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}
