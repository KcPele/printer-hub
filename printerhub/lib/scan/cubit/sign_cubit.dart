import 'dart:math';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/scan/signature.dart';

class SignState extends Equatable {
  const new({
    this.loading = true,
    this.signature,
    this.aspect = 2,
    this.strokes = const [],
    this.page = 0,
    this.x = 0.58,
    this.y = 0.82,
    this.width = 0.32,
  });

  /// True until the phone has been asked for a signature kept earlier.
  final bool loading;

  /// The signature to place. Null while one is still to be drawn.
  final Uint8List? signature;

  /// How wide [signature] is to its height.
  final double aspect;

  /// What has been drawn on the pad so far.
  final List<SignatureStroke> strokes;

  /// Which sheet the signature goes on, counting from zero.
  final int page;

  /// Where on the sheet, and how wide, in parts of the sheet.
  final double x;
  final double y;
  final double width;

  /// True when there is ink on the pad.
  bool get drawn => strokes.any((stroke) => stroke.isNotEmpty);

  SignState _with({
    bool? loading,
    Uint8List? Function()? signature,
    double? aspect,
    List<SignatureStroke>? strokes,
    int? page,
    double? x,
    double? y,
    double? width,
  }) {
    return SignState(
      loading: loading ?? this.loading,
      signature: signature == null ? this.signature : signature(),
      aspect: aspect ?? this.aspect,
      strokes: strokes ?? this.strokes,
      page: page ?? this.page,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    signature?.length,
    aspect,
    strokes,
    page,
    x,
    y,
    width,
  ];
}

/// Signs a page of a scan: draws a signature, or takes the one kept on
/// this phone, and says where on which sheet it goes.
class SignCubit extends Cubit<SignState> {
  new({
    required this._store,
    required this._pages,
    required this._sheetAspect,
    PlacedSignature? placed,
  }) : super(
         placed == null
             // On the last sheet, where a signature usually goes.
             ? SignState(page: _pages - 1)
             : SignState(
                 page: placed.page.clamp(0, _pages - 1),
                 x: placed.x,
                 y: placed.y,
                 width: placed.width,
               ),
       );

  final SignatureStore _store;

  /// How many sheets the scan has.
  final int _pages;

  /// How wide a sheet is to its height.
  final double _sheetAspect;

  /// The narrowest and the widest a signature is set, in parts of a sheet.
  static const double minWidth = 0.15;
  static const double maxWidth = 0.7;

  /// Asks the phone for the signature kept earlier.
  Future<void> load() async {
    final kept = await _store.read();
    final aspect = kept == null ? null : signatureAspect(kept);
    if (isClosed) return;
    emit(
      aspect == null
          ? state._with(loading: false)
          : _fitted(
              state._with(
                loading: false,
                signature: () => kept,
                aspect: aspect,
              ),
            ),
    );
  }

  /// Begins a line on the pad at [point].
  void begin(Point<double> point) {
    emit(
      state._with(
        strokes: [
          ...state.strokes,
          [point],
        ],
      ),
    );
  }

  /// Carries the line being drawn on to [point].
  void drawTo(Point<double> point) {
    if (state.strokes.isEmpty) return;
    emit(
      state._with(
        strokes: [
          ...state.strokes.take(state.strokes.length - 1),
          [...state.strokes.last, point],
        ],
      ),
    );
  }

  /// Wipes the pad.
  void wipe() => emit(state._with(strokes: const []));

  /// Takes what is on the pad, [width] by [height], as the signature, and
  /// keeps it on the phone for next time.
  Future<void> use({required double width, required double height}) async {
    final png = signaturePng(state.strokes, width: width, height: height);
    final aspect = png == null ? null : signatureAspect(png);
    if (png == null || aspect == null) return;
    await _store.save(png);
    if (isClosed) return;
    emit(
      _fitted(
        state._with(signature: () => png, aspect: aspect, strokes: const []),
      ),
    );
  }

  /// Goes back to the pad to draw another, and forgets the one kept.
  Future<void> redraw() async {
    await _store.clear();
    if (!isClosed) emit(state._with(signature: () => null));
  }

  /// Moves the signature by [dx] and [dy], in parts of the sheet.
  void move(double dx, double dy) {
    emit(_fitted(state._with(x: state.x + dx, y: state.y + dy)));
  }

  /// Makes the signature [width] of the sheet wide.
  void resize(double width) => emit(_fitted(state._with(width: width)));

  /// Puts the signature on sheet [page].
  void onPage(int page) {
    emit(state._with(page: page.clamp(0, _pages - 1)));
  }

  /// The signature where it has been put, or null when there is none.
  PlacedSignature? get placed {
    final signature = state.signature;
    if (signature == null) return null;
    return PlacedSignature(
      png: signature,
      page: state.page,
      x: state.x,
      y: state.y,
      width: state.width,
    );
  }

  /// [wanted] with the signature kept whole on the sheet.
  SignState _fitted(SignState wanted) {
    final width = wanted.width.clamp(minWidth, maxWidth);
    // Its height as a part of the sheet's height.
    final height = min(1, width / wanted.aspect * _sheetAspect).toDouble();
    return wanted._with(
      width: width,
      x: wanted.x.clamp(0, 1 - width),
      y: wanted.y.clamp(0, 1 - height),
    );
  }
}
