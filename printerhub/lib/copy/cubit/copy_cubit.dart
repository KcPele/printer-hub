import 'dart:async';
import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:printerhub/library/library.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/scan/scan.dart';
import 'package:printers_repository/printers_repository.dart';

enum CopyStep {
  /// Saying how many, and how.
  choosing,

  /// The scanner is at work.
  scanning,

  /// The printer is at work.
  printing,

  /// The copies are made.
  done,
}

class CopyState extends Equatable {
  const new({
    this.step = CopyStep.choosing,
    this.copies = 1,
    this.color = true,
    this.fromFeeder = false,
    this.scanned = 0,
    this.progress,
    this.failure,
    this.error,
  });

  final CopyStep step;

  /// How many copies to make.
  final int copies;

  /// False copies in black and white.
  final bool color;

  /// True takes the pages from the document feeder, not the glass.
  final bool fromFeeder;

  /// How many pages have been scanned so far.
  final int scanned;

  /// Where the print has got to, while [CopyStep.printing].
  final PrintProgress? progress;

  /// Why the copy stopped: a scan code such as `scan.feeder_empty`, a
  /// print code such as `ipp.job-aborted`, or `copy.unreadable`. Pass it
  /// to `CopyWords.failure`.
  final String? failure;

  /// Why the backend would not record the scan or the print. Pass it to
  /// `errorMessage`.
  final ApiException? error;

  CopyState _with({
    CopyStep? step,
    int? copies,
    bool? color,
    bool? fromFeeder,
    int? scanned,
    PrintProgress? progress,
    String? failure,
    ApiException? error,
  }) {
    return CopyState(
      step: step ?? this.step,
      copies: copies ?? this.copies,
      color: color ?? this.color,
      fromFeeder: fromFeeder ?? this.fromFeeder,
      scanned: scanned ?? this.scanned,
      progress: progress,
      failure: failure,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    step,
    copies,
    color,
    fromFeeder,
    scanned,
    progress,
    failure,
    error,
  ];
}

/// Copies on one printer: scans what is on its glass or in its feeder,
/// then prints that, as many times as asked.
///
/// It is the app's own scan followed by its own print, so each is
/// recorded in the history and settled by `JobRecovery` like any other.
class CopyCubit extends Cubit<CopyState> {
  new({
    required PrintersRepository printersRepository,
    required JobsRepository jobsRepository,
    required DocumentsRepository documentsRepository,
    required Library library,
    required PrintDocuments documents,
    required ScanSharer sharer,
    required ScanTextReader textReader,
    required PageCamera camera,
    required String organizationId,
    required PrinterRead printer,
    required String name,
    Directory? directory,
  }) : _scan = ScanCubit(
         printersRepository: printersRepository,
         jobsRepository: jobsRepository,
         documentsRepository: documentsRepository,
         library: library,
         sharer: sharer,
         textReader: textReader,
         camera: camera,
         picker: documents.picker,
         renderer: documents.renderer,
         organizationId: organizationId,
         printer: printer,
         name: name,
         directory: directory,
       ),
       _print = PrintCubit(
         printersRepository: printersRepository,
         jobsRepository: jobsRepository,
         documents: documents,
         organizationId: organizationId,
         printer: printer,
       ),
       super(const CopyState()) {
    _scanning = _scan.stream.listen((scan) {
      final pages = scan.progress?.pages.length;
      if (pages != null && state.step == CopyStep.scanning) {
        emit(state._with(scanned: scan.pages.length + pages));
      }
    });
    _printing = _print.stream.listen((print) {
      if (state.step == CopyStep.printing && print.progress != null) {
        emit(state._with(progress: print.progress));
      }
    });
  }

  /// The most copies asked for at once.
  static const int maxCopies = 99;

  final ScanCubit _scan;
  final PrintCubit _print;
  late final StreamSubscription<ScanState> _scanning;
  late final StreamSubscription<PrintState> _printing;

  /// True once the person has stopped the copy under way.
  bool _stopped = false;

  /// Changes how many copies, between one and [maxCopies].
  void setCopies(int copies) {
    if (state.step != CopyStep.choosing) return;
    emit(state._with(copies: copies.clamp(1, maxCopies)));
  }

  /// Changes whether the copies are in colour.
  void setColor({required bool color}) {
    if (state.step == CopyStep.choosing) emit(state._with(color: color));
  }

  /// Changes where the pages are taken from.
  void setFromFeeder({required bool fromFeeder}) {
    if (state.step == CopyStep.choosing) {
      emit(state._with(fromFeeder: fromFeeder));
    }
  }

  /// Scans, then prints.
  Future<void> copy() async {
    if (state.step != CopyStep.choosing) return;
    _stopped = false;
    emit(state._with(step: CopyStep.scanning, scanned: 0));

    _scan
      ..startOver()
      ..change(
        ScanChoices(
          source: state.fromFeeder ? 'adf' : 'platen',
          color: state.color ? 'color' : 'grayscale',
        ),
      );
    await _scan.scan();
    if (isClosed) return;
    // Stopped part way: what was scanned is not printed.
    if (_stopped) return emit(state._with(step: CopyStep.choosing));
    if (_scan.state.pages.isEmpty || _scan.state.failure != null) {
      return _fail(
        _scan.state.failure ?? 'copy.nothing_scanned',
        _scan.state.error,
      );
    }
    await _scan.save();
    if (isClosed) return;
    final file = _scan.state.files.firstOrNull;
    if (_scan.state.step != ScanStep.saved || file == null) {
      return _fail(_scan.state.failure ?? 'scan.storage');
    }

    emit(
      state._with(step: CopyStep.printing, scanned: _scan.state.pages.length),
    );
    await _print.open(PickedDocument.fromFile(file));
    if (isClosed) return;
    if (_print.state.step != PrintStep.ready) return _fail('copy.unreadable');
    _print.change(
      _print.state.choices.copyWith(
        copies: state.copies,
        color: state.color ? 'auto' : 'monochrome',
      ),
    );
    await _print.print();
    if (isClosed) return;

    final last = _print.state.progress;
    if (last?.stage == PrintStage.completed) {
      emit(state._with(step: CopyStep.done));
    } else if (_stopped) {
      emit(state._with(step: CopyStep.choosing));
    } else {
      // Refused by the backend before anything was sent, or failed on
      // the way: the print says which.
      _fail(last?.errorCode ?? 'copy.not_printed', _print.state.error);
    }
  }

  void _fail(String code, [ApiException? error]) {
    emit(
      state._with(
        step: CopyStep.choosing,
        // What the backend said is the reason, when it said anything.
        failure: error == null ? code : null,
        error: error,
      ),
    );
  }

  /// Stops whichever of the scanner and the printer is at work.
  Future<void> cancel() async {
    if (state.step == CopyStep.scanning) {
      _stopped = true;
      await _scan.cancel();
    } else if (state.step == CopyStep.printing) {
      _stopped = true;
      await _print.cancel();
    }
  }

  /// Goes back to make more copies.
  void again() {
    if (state.step == CopyStep.done) {
      emit(state._with(step: CopyStep.choosing, scanned: 0));
    }
  }

  @override
  Future<void> close() async {
    await _scanning.cancel();
    await _printing.cancel();
    await _scan.close();
    await _print.close();
    await super.close();
  }
}
