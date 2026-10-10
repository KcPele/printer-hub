import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/photo_sheet.dart';

class PhotoSheetState extends Equatable {
  const new({
    this.photos = const [],
    this.layout = PhotoLayout.one,
    this.paper = ScanPaper.a4,
    this.working = false,
    this.file,
    this.failure,
  });

  /// The photos chosen, in order.
  final List<PickedDocument> photos;
  final PhotoLayout layout;
  final ScanPaper paper;

  /// True while the sheet is being made.
  final bool working;

  /// The sheet, once it is made: a PDF to print or share.
  final File? file;

  /// Why the sheet could not be made: `tools.unreadable`.
  final String? failure;

  PhotoSheetState _with({
    List<PickedDocument>? photos,
    PhotoLayout? layout,
    ScanPaper? paper,
    bool working = false,
    File? file,
    String? failure,
  }) {
    return PhotoSheetState(
      photos: photos ?? this.photos,
      layout: layout ?? this.layout,
      paper: paper ?? this.paper,
      working: working,
      file: file,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
    photos,
    layout,
    paper.name,
    working,
    file?.path,
    failure,
  ];
}

/// Lays photos the person chooses out on a sheet to print: one, two, or
/// four to a page, or a sheet of passport photos.
class PhotoSheetCubit extends Cubit<PhotoSheetState> {
  new({
    required this._picker,
    required this._sharer,
    required this._name,
    Directory? directory,
  }) : _directory = directory ?? Directory.systemTemp,
       super(const PhotoSheetState());

  final DocumentPicker _picker;
  final ScanSharer _sharer;
  final String _name;
  final Directory _directory;
  bool _choosing = false;

  /// Asks for photos, and adds them to the ones already chosen.
  Future<void> choose() async {
    if (_choosing || state.working) return;
    _choosing = true;
    try {
      final chosen = await _picker.pickPictures();
      if (isClosed || chosen.isEmpty) return;
      emit(state._with(photos: [...state.photos, ...chosen]));
    } finally {
      _choosing = false;
    }
  }

  /// Takes one photo out.
  void remove(PickedDocument photo) {
    if (state.working) return;
    emit(
      state._with(
        photos: [
          for (final other in state.photos)
            if (other != photo) other,
        ],
      ),
    );
  }

  /// Changes how the photos are laid out. A sheet already made is no
  /// longer what was asked for, and is dropped.
  void setLayout(PhotoLayout layout) {
    if (!state.working) emit(state._with(layout: layout));
  }

  /// Changes the paper the sheet is made for.
  void setPaper(ScanPaper paper) {
    if (!state.working) emit(state._with(paper: paper));
  }

  /// Makes the sheet.
  Future<void> make() async {
    if (state.working || state.photos.isEmpty) return;
    emit(state._with(working: true));
    try {
      final file = await photoSheet(
        photos: [for (final photo in state.photos) File(photo.path)],
        layout: state.layout,
        paper: state.paper,
        name: _name,
        directory: _directory,
      );
      if (!isClosed) emit(state._with(file: file));
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
