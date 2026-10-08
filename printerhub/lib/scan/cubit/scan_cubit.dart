import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printers_repository/printers_repository.dart';

enum ScanStep {
  /// Saying what to scan and how.
  choosing,

  /// The scanner is at work.
  scanning,

  /// Looking over the pages that arrived.
  review,

  /// Putting the pages together.
  saving,

  /// The scan is a file, or several, ready to share.
  saved,
}

/// Whether a finished scan has been put in the workspace.
enum ScanKept {
  /// It is on this phone only.
  no,

  /// It is on its way.
  keeping,

  /// The workspace has it.
  yes,
}

class ScanState extends Equatable {
  const new({
    this.step = ScanStep.choosing,
    this.choices = const ScanChoices(),
    this.card = false,
    this.name = '',
    this.pages = const [],
    this.progress,
    this.failure,
    this.error,
    this.files = const [],
    this.kept = ScanKept.no,
    this.textRead,
    this.cameraPages = const {},
  });

  final ScanStep step;
  final ScanChoices choices;

  /// True when an ID card is being scanned: its front, then its back,
  /// from the glass, to be put on one sheet.
  final bool card;

  /// True when a card's front has been scanned and its back has not.
  bool get awaitsBack => card && pages.length.isOdd;

  /// What the scan is called, and its file named after.
  final String name;

  /// The pages so far, in order.
  final List<ScannedPage> pages;

  /// Where the scan has got to, while [ScanStep.scanning].
  final ScanProgress? progress;

  /// Why the last scan stopped, or the pages could not be put together:
  /// a code such as `scan.feeder_empty`. Pass it to `ScanWords.failure`.
  final String? failure;

  /// Why the backend would not record the scan. Pass it to `errorMessage`.
  final ApiException? error;

  /// The finished scan, once [ScanStep.saved].
  final List<File> files;

  /// Whether the finished scan is in the workspace too.
  final ScanKept kept;

  /// The pages that came from the phone's camera, not the printer's
  /// scanner, by their file's path.
  final Set<String> cameraPages;

  /// True when [page] was taken with the phone's camera.
  bool fromCamera(ScannedPage page) => cameraPages.contains(page.file.path);

  /// Whether the words of a kept scan were read and kept with it. Null
  /// when they were not asked for, false when the phone could not read
  /// them.
  final bool? textRead;

  ScanState _with({
    ScanStep? step,
    ScanChoices? choices,
    bool? card,
    String? name,
    List<ScannedPage>? pages,
    ScanProgress? progress,
    String? failure,
    ApiException? error,
    List<File> files = const [],
    ScanKept kept = ScanKept.no,
    bool? textRead,
    Set<String>? cameraPages,
  }) {
    return ScanState(
      step: step ?? this.step,
      choices: choices ?? this.choices,
      card: card ?? this.card,
      name: name ?? this.name,
      pages: pages ?? this.pages,
      progress: progress,
      failure: failure,
      error: error,
      files: files,
      kept: kept,
      textRead: textRead,
      cameraPages: cameraPages ?? this.cameraPages,
    );
  }

  @override
  List<Object?> get props => [
    step,
    choices,
    card,
    name,
    pages,
    progress,
    failure,
    error,
    [for (final file in files) file.path],
    kept,
    textRead,
    cameraPages,
  ];
}

/// Scans on one printer: say how, scan, look the pages over, scan more,
/// and keep the result as a file to share. Each run of the scanner is
/// recorded as a job.
class ScanCubit extends Cubit<ScanState> {
  new({
    required this._printersRepository,
    required this._jobsRepository,
    required this._documentsRepository,
    required this._sharer,
    required this._textReader,
    required this._camera,
    required this._organizationId,
    required this._printer,
    required String name,
    Directory? directory,
  }) : _directory = directory ?? Directory.systemTemp,
       super(
         ScanState(name: name, choices: fitted(const ScanChoices(), _printer)),
       );

  final PrintersRepository _printersRepository;
  final JobsRepository _jobsRepository;
  final DocumentsRepository _documentsRepository;
  final ScanSharer _sharer;
  final ScanTextReader _textReader;
  final PageCamera _camera;
  bool _atCamera = false;
  final String _organizationId;
  final PrinterRead _printer;
  final Directory _directory;

  PrinterScan? _scan;

  /// The files of this scan the workspace has, and the records of those
  /// whose file did not arrive, by the file's path.
  final Map<String, StoredDocument> _kept = {};
  final Map<String, StoredDocument> _waiting = {};

  /// [choices] with anything [printer] does not offer changed to something
  /// it does.
  static ScanChoices fitted(ScanChoices choices, PrinterRead printer) {
    final offers = printer.capabilities?.scan;
    if (offers == null) return choices;
    final sources = [for (final source in offers.sources) ?source.json];
    final colors = [for (final mode in offers.colorModes) ?mode.json];
    final source = sources.isEmpty || sources.contains(choices.source)
        ? choices.source
        : sources.first;
    final dpi = offers.resolutionsDpi;

    return choices.copyWith(
      source: source,
      color: colors.isEmpty || colors.contains(choices.color)
          ? null
          : colors.first,
      duplex: choices.duplex && source == 'adf' && offers.adfDuplex,
      resolutionDpi: dpi.isEmpty || dpi.contains(choices.resolutionDpi)
          ? null
          : dpi.reduce(
              (best, next) =>
                  (next - choices.resolutionDpi).abs() <
                      (best - choices.resolutionDpi).abs()
                  ? next
                  : best,
            ),
      mediaSize: () {
        final paper = ScanPaper.named(choices.mediaSize);
        if (paper.fits(offers.maxWidthMm, offers.maxHeightMm)) {
          return choices.mediaSize;
        }
        return ScanPaper.all
            .where((size) => size.fits(offers.maxWidthMm, offers.maxHeightMm))
            .firstOrNull
            ?.name;
      },
    );
  }

  /// True when [printer] can scan an ID card: it has a glass to lay one
  /// on, or has not said what it has.
  static bool takesCards(PrinterRead printer) {
    final sources = [
      for (final source
          in printer.capabilities?.scan.sources ?? const <Never>[])
        ?source.json,
    ];
    return sources.isEmpty || sources.contains('platen');
  }

  bool get _settled =>
      state.step == ScanStep.choosing || state.step == ScanStep.review;

  /// What the scanner is asked for. A card is always scanned from the
  /// glass, one side at a time, and kept as a PDF. The paper chosen is the
  /// sheet both sides go on, not the area scanned.
  ScanChoices get _asked => state.card
      ? state.choices.copyWith(
          source: 'platen',
          duplex: false,
          format: 'application/pdf',
          mediaSize: () => ScanPaper.card.name,
        )
      : state.choices;

  /// Scans an ID card, or goes back to scanning documents. Chosen before
  /// the first page, since the two are put together differently.
  void asCard({required bool card}) {
    if (state.step == ScanStep.choosing && takesCards(_printer)) {
      emit(state._with(card: card));
    }
  }

  /// Changes how to scan.
  void change(ScanChoices choices) {
    if (_settled) emit(state._with(choices: fitted(choices, _printer)));
  }

  /// Changes what the scan is called.
  void rename(String name) {
    if (_settled) emit(state._with(name: name));
  }

  /// Scans, adding the pages that arrive to the ones already there.
  Future<void> scan() async {
    if (!_settled) return;
    final before = state.step;
    final choices = _asked;
    emit(state._with(step: ScanStep.scanning));

    final Job job;
    try {
      job = await _jobsRepository.startScan(
        organizationId: _organizationId,
        printerId: _printer.id,
        title: state.name,
        choices: choices,
        connectionId: _printer.connections
            .where((connection) => connection.type == ConnectionType.escl)
            .firstOrNull
            ?.id,
      );
    } on ApiException catch (error) {
      emit(state._with(step: before, error: error));
      return;
    }

    final paper = state.card
        ? ScanPaper.card
        : ScanPaper.named(choices.mediaSize);
    final scan = _printersRepository.scan(
      printer: _printer,
      request: ScanRequest(
        source: choices.source,
        color: choices.color == 'color',
        duplex: choices.duplex,
        resolutionDpi: choices.resolutionDpi,
        widthMm: paper.widthMm,
        heightMm: paper.heightMm,
      ),
    );
    _scan = scan;

    // The record is kept in order, but the screen does not wait on it.
    var records = Future<void>.value();
    String? recorded;
    ScanProgress? last;
    await for (final progress in scan.progress) {
      last = progress;
      if (!isClosed) emit(state._with(progress: progress));

      final update = _record(progress, scan);
      if (update != null && update.status != recorded) {
        recorded = update.status;
        records = records.then(
          (_) => _jobsRepository.report(_organizationId, job.id, update),
        );
      }
    }
    await records;
    _scan = null;
    if (isClosed) return;

    final pages = [...state.pages, ...?last?.pages];
    emit(
      state._with(
        step: pages.isEmpty ? ScanStep.choosing : ScanStep.review,
        pages: pages,
        failure: last?.stage == ScanStage.failed ? last?.errorCode : null,
      ),
    );
  }

  /// Takes pages with the phone's camera, and adds them to the ones
  /// already there. For a printer with no scanner, and as another way
  /// where there is one. They are kept as a camera scan, never as the
  /// printer's.
  Future<void> useCamera() async {
    if (!_settled || state.card || _atCamera) return;
    _atCamera = true;
    try {
      final taken = await _camera.capture();
      if (isClosed || taken.isEmpty) return;
      emit(
        state._with(
          step: ScanStep.review,
          pages: [
            ...state.pages,
            for (final file in taken)
              ScannedPage(file: file, mimeType: 'image/jpeg'),
          ],
          cameraPages: {
            ...state.cameraPages,
            for (final file in taken) file.path,
          },
        ),
      );
    } on Object {
      if (!isClosed) emit(state._with(failure: 'scan.camera'));
    } finally {
      _atCamera = false;
    }
  }

  /// Stops the scanner. The pages that have arrived are kept.
  Future<void> cancel() async {
    await _scan?.cancel();
  }

  /// Takes one page out.
  void remove(ScannedPage page) {
    if (state.step != ScanStep.review) return;
    _delete([page.file]);
    final pages = [
      for (final other in state.pages)
        if (other != page) other,
    ];
    emit(
      state._with(
        step: pages.isEmpty ? ScanStep.choosing : ScanStep.review,
        pages: pages,
      ),
    );
  }

  /// Moves the page at [from] so that it ends up at [to].
  void move(int from, int to) {
    if (state.step != ScanStep.review) return;
    final pages = [...state.pages];
    pages.insert(to, pages.removeAt(from));
    emit(state._with(pages: pages));
  }

  /// Puts the pages together as a file, or as a file each.
  Future<void> save() async {
    if (state.step != ScanStep.review) return;
    emit(state._with(step: ScanStep.saving));
    try {
      final files = await assembleScan(
        pages: state.pages,
        name: state.name,
        format: _asked.format,
        directory: _directory,
        paper: ScanPaper.named(state.choices.mediaSize),
        card: state.card,
      );
      if (!isClosed) emit(state._with(step: ScanStep.saved, files: files));
    } on Object {
      if (!isClosed) {
        emit(state._with(step: ScanStep.review, failure: 'scan.storage'));
      }
    }
  }

  /// Hands the finished scan to the phone's share sheet.
  Future<void> share() async {
    if (state.step != ScanStep.saved) return;
    await _sharer.share(state.files, name: state.name);
  }

  /// Puts the finished scan in the workspace, for the other members and
  /// the person's other devices. Asked again after a failure, it sends
  /// only what did not arrive.
  ///
  /// With [readText], the words in the pages are read on the phone first
  /// and kept with the scan, so the workspace can find it by what it says.
  /// That is for a workspace with `local_ocr` switched on.
  Future<void> keep({bool readText = false}) async {
    if (state.step != ScanStep.saved || state.kept != ScanKept.no) return;
    final files = state.files;
    emit(state._with(files: files, kept: ScanKept.keeping));
    bool? textRead;
    try {
      for (final (index, file) in files.indexed) {
        if (_kept.containsKey(file.path)) continue;
        final waiting = _waiting[file.path];
        final name = file.uri.pathSegments.last;
        final pdf = name.endsWith('.pdf');
        String? text;
        if (readText && waiting == null) {
          // One file holds every page; otherwise a file is its page.
          final pages = files.length == 1 ? state.pages : [state.pages[index]];
          try {
            text = await _textReader.read([
              for (final page in pages)
                if (page.mimeType != 'application/pdf') page.file,
            ]);
            textRead ??= true;
          } on Object {
            // The scan is kept all the same, and found by its name.
            textRead = false;
          }
        }
        try {
          _kept[file.path] = waiting != null
              ? await _documentsRepository.finish(
                  organizationId: _organizationId,
                  document: waiting,
                  file: file,
                )
              : await _documentsRepository.keep(
                  organizationId: _organizationId,
                  file: file,
                  name: Uri.decodeComponent(name),
                  mimeType: pdf ? 'application/pdf' : 'image/jpeg',
                  // One PDF holds every page, or every two sides of a
                  // card; otherwise a file is a page.
                  pageCount: files.length > 1
                      ? 1
                      : state.card
                      ? (state.pages.length + 1) ~/ 2
                      : state.pages.length,
                  // A scan with a page from the camera is a camera scan,
                  // and the printer's only when the printer made some of
                  // it.
                  source: state.pages.any(state.fromCamera)
                      ? 'camera_scan'
                      : 'printer_scan',
                  printerId: state.pages.every(state.fromCamera)
                      ? null
                      : _printer.id,
                  text: text,
                );
          _waiting.remove(file.path);
        } on UploadInterrupted catch (interrupted) {
          _waiting[file.path] = interrupted.document;
          rethrow;
        }
      }
      if (!isClosed) {
        emit(state._with(files: files, kept: ScanKept.yes, textRead: textRead));
      }
    } on UploadInterrupted {
      if (!isClosed) {
        emit(state._with(files: files, failure: 'scan.keep_interrupted'));
      }
    } on ApiException catch (error) {
      if (!isClosed) emit(state._with(files: files, error: error));
    }
  }

  /// Goes back to the pages, to add to them or change their order.
  void edit() {
    if (state.step != ScanStep.saved || state.kept == ScanKept.keeping) {
      return;
    }
    _delete(state.files);
    emit(state._with(step: ScanStep.review));
  }

  /// Throws the pages away and begins again.
  void startOver() {
    if (state.step == ScanStep.scanning ||
        state.step == ScanStep.saving ||
        state.kept == ScanKept.keeping) {
      return;
    }
    _delete([for (final page in state.pages) page.file, ...state.files]);
    emit(ScanState(name: state.name, choices: state.choices, card: state.card));
  }

  static void _delete(Iterable<File> files) {
    for (final file in files) {
      if (file.existsSync()) file.deleteSync();
    }
  }

  /// What to tell the backend about a step, or null for a step that
  /// changes nothing in the job's record.
  static JobUpdate? _record(ScanProgress progress, PrinterScan scan) {
    final connectionId = scan.connectionIdOf(progress.connection);
    return switch (progress.stage) {
      ScanStage.connecting => JobUpdate(
        status: 'processing',
        connectionId: connectionId,
      ),
      ScanStage.scanning => JobUpdate(
        status: 'scanning',
        connectionId: connectionId,
      ),
      ScanStage.completed => JobUpdate(
        status: 'completed',
        connectionId: connectionId,
        pageCount: progress.pages.length,
      ),
      ScanStage.cancelled => JobUpdate(
        status: 'cancelled',
        connectionId: connectionId,
      ),
      ScanStage.failed => JobUpdate(
        status: 'failed',
        connectionId: connectionId,
        errorCode: progress.errorCode,
        errorMessage: progress.errorMessage,
      ),
    };
  }
}
