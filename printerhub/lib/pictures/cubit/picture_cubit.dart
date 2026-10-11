import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/pictures/picture_edits.dart';

/// What is being done to a picture that is open.
enum PictureTool {
  /// Looked at: pinched larger, moved about.
  none,

  /// A box is being drawn around the part to keep.
  crop,

  /// Lines are being drawn over it with a highlighter.
  highlight,
}

class PictureState extends Equatable {
  const new({
    required this.file,
    this.width = 0,
    this.height = 0,
    this.tool = PictureTool.none,
    this.crop = CropBox.start,
    this.strokes = const [],
    this.color = HighlightColor.yellow,
    this.pen = HighlightPen.thick,
    this.working = false,
    this.failed = false,
    this.changed = false,
  });

  /// The picture as it stands, with every change so far.
  final File file;

  /// Its size in pixels. Zero until it has been read.
  final int width;
  final int height;

  final PictureTool tool;

  /// The part kept, while [PictureTool.crop].
  final CropBox crop;

  /// The lines drawn, while [PictureTool.highlight].
  final List<PictureStroke> strokes;

  /// The highlighter in hand: its ink, and how wide it draws.
  final HighlightColor color;
  final HighlightPen pen;

  /// True while a change is being made to the picture.
  final bool working;

  /// True when the picture cannot be read, or a change could not be made.
  final bool failed;

  /// True once the picture is no longer as it was opened.
  final bool changed;

  /// True once its size is known, so it can be shown and worked on.
  bool get ready => width > 0 && height > 0;

  @override
  List<Object?> get props => [
    file.path,
    width,
    height,
    tool,
    crop,
    strokes,
    color,
    pen,
    working,
    failed,
    changed,
  ];
}

/// A picture, open full screen: cropped, highlighted, turned, and each
/// change taken back if it was a mistake. The picture it was opened on is
/// never touched: every change makes a new one.
class PictureCubit extends Cubit<PictureState> {
  new({required File picture, Directory? directory})
    : _directory = directory ?? Directory.systemTemp,
      super(PictureState(file: picture));

  final Directory _directory;

  /// The picture before each change, the latest last.
  final List<({File file, int width, int height})> _before = [];
  int _made = 0;

  PictureState _with({
    File? file,
    int? width,
    int? height,
    PictureTool? tool,
    CropBox? crop,
    List<PictureStroke>? strokes,
    HighlightColor? color,
    HighlightPen? pen,
    bool working = false,
    bool failed = false,
  }) {
    return PictureState(
      file: file ?? state.file,
      width: width ?? state.width,
      height: height ?? state.height,
      tool: tool ?? state.tool,
      crop: crop ?? state.crop,
      strokes: strokes ?? state.strokes,
      color: color ?? state.color,
      pen: pen ?? state.pen,
      working: working,
      failed: failed,
      changed: _before.isNotEmpty,
    );
  }

  /// Reads how large the picture is, so it can be shown.
  Future<void> load() async {
    try {
      final bytes = await state.file.readAsBytes();
      final size = await Isolate.run(() => pictureSize(bytes));
      if (isClosed) return;
      emit(
        size == null
            ? _with(failed: true)
            : _with(width: size.width, height: size.height),
      );
    } on Object {
      if (!isClosed) emit(_with(failed: true));
    }
  }

  /// Takes up a tool, or with [PictureTool.none] puts it down without
  /// using it.
  void choose(PictureTool tool) {
    if (!state.ready || state.working) return;
    emit(_with(tool: tool, crop: CropBox.start, strokes: const []));
  }

  /// Moves the edges of the box around what is kept.
  void cropTo(CropBox crop) {
    if (state.tool == PictureTool.crop && !state.working) {
      emit(_with(crop: crop));
    }
  }

  /// Takes up a highlighter of another ink, or another width. Lines
  /// already drawn keep theirs.
  void pick({HighlightColor? color, HighlightPen? pen}) {
    if (state.tool == PictureTool.highlight && !state.working) {
      emit(_with(color: color, pen: pen));
    }
  }

  /// Begins a line of highlighter at [point], in parts of the picture.
  void begin(Point<double> point) {
    if (state.tool != PictureTool.highlight || state.working) return;
    emit(
      _with(
        strokes: [
          ...state.strokes,
          PictureStroke(
            points: [_inside(point)],
            color: state.color,
            pen: state.pen,
          ),
        ],
      ),
    );
  }

  /// Carries the line on to [point].
  void drawTo(Point<double> point) {
    if (state.tool != PictureTool.highlight ||
        state.working ||
        state.strokes.isEmpty) {
      return;
    }
    emit(
      _with(
        strokes: [
          ...state.strokes.take(state.strokes.length - 1),
          state.strokes.last.to(_inside(point)),
        ],
      ),
    );
  }

  static Point<double> _inside(Point<double> point) =>
      Point(point.x.clamp(0, 1), point.y.clamp(0, 1));

  /// Makes the change the tool in hand was taken up for.
  Future<void> apply() async {
    final tool = state.tool;
    final crop = state.crop;
    final strokes = state.strokes;
    if (tool == PictureTool.none) return;
    if (tool == PictureTool.highlight && strokes.isEmpty) {
      emit(_with(tool: PictureTool.none));
      return;
    }
    await _change(
      (bytes) => tool == PictureTool.crop
          ? croppedPicture(bytes, crop)
          : highlightedPicture(bytes, strokes),
    );
  }

  /// Turns the picture a quarter turn to the right.
  Future<void> turn() async {
    if (state.tool != PictureTool.none) return;
    await _change(turnedPicture);
  }

  Future<void> _change(Uint8List Function(Uint8List bytes) change) async {
    if (!state.ready || state.working) return;
    emit(_with(working: true));
    try {
      final bytes = await state.file.readAsBytes();
      final changed = await Isolate.run(() => change(bytes));
      final size = pictureSize(changed)!;
      final file = File(
        '${_directory.path}/picture-${DateTime.now().microsecondsSinceEpoch}'
        '-${_made++}.jpg',
      );
      await file.writeAsBytes(changed, flush: true);
      if (isClosed) return;
      _before.add((file: state.file, width: state.width, height: state.height));
      emit(
        _with(
          file: file,
          width: size.width,
          height: size.height,
          tool: PictureTool.none,
          strokes: const [],
        ),
      );
    } on Object {
      if (!isClosed) emit(_with(failed: true));
    }
  }

  /// Takes back the last change.
  void undo() {
    if (_before.isEmpty || state.working) return;
    final before = _before.removeLast();
    emit(
      _with(
        file: before.file,
        width: before.width,
        height: before.height,
        tool: PictureTool.none,
        strokes: const [],
      ),
    );
  }
}
