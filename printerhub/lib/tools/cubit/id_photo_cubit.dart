import 'dart:io';
import 'dart:isolate';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/documents/document_sources.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/pictures/picture_edits.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/id_photo.dart';
import 'package:printerhub/tools/photo_sheet.dart';

class IdPhotoState extends Equatable {
  const new({
    this.photo,
    this.width = 0,
    this.height = 0,
    this.size = const IdPhotoSize('35x45', 35, 45),
    this.paper = ScanPaper.a4,
    this.frame = const CropBox(left: 0, top: 0, right: 1, bottom: 1),
    this.working = false,
    this.file,
    this.failure,
  });

  /// The photo chosen.
  final File? photo;

  /// Its size in pixels.
  final int width;
  final int height;

  final IdPhotoSize size;
  final ScanPaper paper;

  /// The part of the photo that is kept: where the person moved and
  /// pinched it to, in the frame of [size].
  final CropBox frame;

  /// True while the sheet is being made.
  final bool working;

  /// The sheet, once it is made: a PDF to print or share.
  final File? file;

  /// Why the photo could not be used: `tools.unreadable`.
  final String? failure;

  /// How many photos one sheet holds.
  int get copies =>
      photosFitOn(paper, widthMm: size.widthMm, heightMm: size.heightMm);

  IdPhotoState _with({
    File? photo,
    int? width,
    int? height,
    IdPhotoSize? size,
    ScanPaper? paper,
    CropBox? frame,
    bool working = false,
    File? file,
    String? failure,
  }) {
    return IdPhotoState(
      photo: photo ?? this.photo,
      width: width ?? this.width,
      height: height ?? this.height,
      size: size ?? this.size,
      paper: paper ?? this.paper,
      frame: frame ?? this.frame,
      working: working,
      file: file,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
    photo?.path,
    width,
    height,
    size,
    paper.name,
    frame,
    working,
    file?.path,
    failure,
  ];
}

/// Makes a sheet of ID photos: a photo the person chooses, framed to an
/// official size, as many to a sheet as it holds.
class IdPhotoCubit extends Cubit<IdPhotoState> {
  new({
    required this._picker,
    required this._sharer,
    required this._keep,
    required this._name,
    Directory? directory,
  }) : _directory = directory ?? Directory.systemTemp,
       super(const IdPhotoState());

  final DocumentPicker _picker;
  final ScanSharer _sharer;
  final KeepFile _keep;
  final String _name;
  final Directory _directory;
  bool _choosing = false;

  /// Asks for a photo, and frames it from the middle.
  Future<void> choose() async {
    if (_choosing || state.working) return;
    _choosing = true;
    try {
      final chosen = await _picker.pickPictures();
      if (isClosed || chosen.isEmpty) return;
      final photo = File(chosen.first.path);
      final bytes = await photo.readAsBytes();
      final size = await Isolate.run(() => pictureSize(bytes));
      if (isClosed) return;
      if (size == null) {
        emit(state._with(failure: 'tools.unreadable'));
        return;
      }
      emit(
        state._with(
          photo: photo,
          width: size.width,
          height: size.height,
          frame: coverBox(
            width: size.width,
            height: size.height,
            aspect: state.size.aspect,
          ),
        ),
      );
    } on FileSystemException {
      if (!isClosed) emit(state._with(failure: 'tools.unreadable'));
    } finally {
      _choosing = false;
    }
  }

  /// Changes the size. The photo is framed afresh, from the middle.
  void setSize(IdPhotoSize size) {
    if (state.working) return;
    emit(
      state._with(
        size: size,
        frame: state.photo == null
            ? null
            : coverBox(
                width: state.width,
                height: state.height,
                aspect: size.aspect,
              ),
      ),
    );
  }

  /// Changes the paper the sheet is made for.
  void setPaper(ScanPaper paper) {
    if (!state.working) emit(state._with(paper: paper));
  }

  /// Keeps the part of the photo the person moved and pinched into the
  /// frame.
  void frameTo(CropBox frame) {
    if (!state.working) emit(state._with(frame: frame));
  }

  /// Makes the sheet.
  Future<void> make() async {
    final photo = state.photo;
    if (photo == null || state.working) return;
    emit(state._with(working: true, file: state.file));
    try {
      final bytes = await photo.readAsBytes();
      final frame = state.frame;
      // Cut away from the screen's thread: a phone's photo is large.
      final framed = await Isolate.run(() => croppedPicture(bytes, frame));
      final file = await idPhotoSheet(
        photo: framed,
        size: state.size,
        paper: state.paper,
        name: _name,
        directory: _directory,
      );
      if (!isClosed) emit(state._with(file: file));
      await _keep(
        file,
        mimeType: 'application/pdf',
        pageCount: 1,
        source: DocumentSources.idPhoto,
      );
    } on Object {
      if (!isClosed) emit(state._with(failure: 'tools.unreadable'));
    }
  }

  /// Hands the sheet to the phone's share sheet.
  Future<void> share() async {
    final file = state.file;
    if (file != null) await _sharer.share([file], name: _name);
  }
}
