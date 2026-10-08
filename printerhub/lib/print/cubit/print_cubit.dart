import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:printerhub/print/documents.dart';
import 'package:printers_repository/printers_repository.dart';

enum PrintStep {
  /// Nothing chosen yet.
  choosing,

  /// Reading the chosen file.
  reading,

  /// A document and how to print it.
  ready,

  /// On its way to the printer, or on it.
  printing,

  /// Over, one way or another.
  finished,
}

/// Why a chosen file cannot be printed.
enum PrintProblem {
  /// Not a PDF or a picture.
  unsupportedFile,

  /// It could not be read as what it claims to be.
  unreadableFile,
}

class PrintState extends Equatable {
  const new({
    this.step = PrintStep.choosing,
    this.document,
    this.preview,
    this.choices = const PrintChoices(),
    this.progress,
    this.problem,
    this.error,
    this.handedToSystem = false,
  });

  final PrintStep step;
  final PickedDocument? document;
  final DocumentPreview? preview;
  final PrintChoices choices;

  /// Where the print has got to, from [PrintStep.printing] on.
  final PrintProgress? progress;
  final PrintProblem? problem;

  /// Why the backend would not record the job. Pass it to `errorMessage`.
  final ApiException? error;

  /// True when the document went to the phone's own print dialog.
  final bool handedToSystem;

  /// True when the phone's own print dialog can be offered instead: it
  /// takes a PDF, and is worth offering when the printer cannot take the
  /// document from the app.
  bool get canUseSystemPrint =>
      step == PrintStep.finished &&
      !handedToSystem &&
      progress?.errorCode == 'print.format_not_supported' &&
      document?.mimeType == 'application/pdf';

  PrintState _with({
    PrintStep? step,
    PrintChoices? choices,
    PrintProgress? progress,
    ApiException? error,
    bool handedToSystem = false,
  }) {
    return PrintState(
      step: step ?? this.step,
      document: document,
      preview: preview,
      choices: choices ?? this.choices,
      progress: progress,
      error: error,
      handedToSystem: handedToSystem,
    );
  }

  @override
  List<Object?> get props => [
    step,
    document,
    preview,
    choices,
    progress,
    problem,
    error,
    handedToSystem,
  ];
}

/// Prints a document on one printer: choose the file, choose how, send it,
/// and follow it, keeping the job's record as it goes.
class PrintCubit extends Cubit<PrintState> {
  new({
    required this._printersRepository,
    required this._jobsRepository,
    required this._documents,
    required this._organizationId,
    required this._printer,
    Job? retryOf,
  }) : _retry = retryOf == null
           ? null
           : (
               jobId: retryOf.id,
               title: retryOf.title,
               choices: retryOf.print ?? const PrintChoices(),
             ),
       _touched = retryOf != null,
       super(
         PrintState(
           choices: fitted(retryOf?.print ?? const PrintChoices(), _printer),
         ),
       );

  final PrintersRepository _printersRepository;
  final JobsRepository _jobsRepository;
  final PrintDocuments _documents;
  final String _organizationId;
  final PrinterRead _printer;

  PrinterPrint? _print;
  bool _choosing = false;

  /// True once the choices are someone's own, and no longer to be replaced
  /// by what a print usually starts from.
  bool _touched;

  /// [choices] with anything [printer] does not offer left to the printer.
  /// Saved settings and old jobs may ask for a tray this printer lacks.
  static PrintChoices fitted(PrintChoices choices, PrinterRead printer) {
    final offers = printer.capabilities?.print;
    if (offers == null) return choices;
    bool offered(String? value, Iterable<String?> options) =>
        value != null && options.contains(value);

    return choices.copyWith(
      copies: choices.copies.clamp(1, offers.maxCopies ?? 99),
      color: offers.color || choices.color == 'monochrome' ? null : 'auto',
      sides: offered(choices.sides, offers.duplexModes.map((mode) => mode.json))
          ? null
          : 'one_sided',
      mediaSize: offered(choices.mediaSize, offers.mediaSizes)
          ? null
          : () => null,
      tray: offered(choices.tray, offers.trays.map((tray) => tray.id))
          ? null
          : () => null,
      quality: offered(choices.quality, offers.qualityModes)
          ? null
          : () => null,
    );
  }

  /// The job that failed or was cancelled, which printing the same
  /// document the same way is another try of.
  ({String jobId, String? title, PrintChoices choices})? _retry;

  /// Lets the person choose a file, and reads it.
  Future<void> choose() async {
    if (_choosing || state.step == PrintStep.printing) return;
    _choosing = true;
    try {
      final document = await _documents.picker.pick();
      if (document == null || isClosed) return;
      if (document.mimeType == null) {
        emit(
          PrintState(
            problem: PrintProblem.unsupportedFile,
            choices: state.choices,
          ),
        );
        return;
      }

      // The choices made so far carry over to the new file.
      final choices = state.choices;
      emit(
        PrintState(
          step: PrintStep.reading,
          document: document,
          choices: choices,
        ),
      );
      try {
        final preview = await _documents.renderer.preview(document);
        emit(
          PrintState(
            step: PrintStep.ready,
            document: document,
            preview: preview,
            choices: choices,
          ),
        );
      } on Object {
        emit(
          PrintState(
            problem: PrintProblem.unreadableFile,
            choices: state.choices,
          ),
        );
      }
    } finally {
      _choosing = false;
    }
  }

  /// Changes how the document is to be printed.
  void change(PrintChoices choices) {
    if (state.step != PrintStep.ready) return;
    _touched = true;
    emit(state._with(choices: choices));
  }

  /// Takes saved settings in place of the choices so far, as far as this
  /// printer offers them. Which pages to print stays as it was.
  void use(PrintChoices saved) {
    if (state.step == PrintStep.printing || state.step == PrintStep.finished) {
      return;
    }
    _touched = true;
    _take(saved);
  }

  /// Takes what a print usually starts from, unless choices were already
  /// made.
  void startFrom(PrintChoices usual) {
    if (_touched ||
        state.step == PrintStep.printing ||
        state.step == PrintStep.finished) {
      return;
    }
    _take(usual);
  }

  void _take(PrintChoices choices) {
    emit(
      PrintState(
        step: state.step,
        document: state.document,
        preview: state.preview,
        problem: state.problem,
        choices: fitted(
          choices.copyWith(pageRanges: () => state.choices.pageRanges),
          _printer,
        ),
      ),
    );
  }

  /// Sends the document to the printer and follows it to the end.
  Future<void> print() async {
    final document = state.document;
    final preview = state.preview;
    if (state.step != PrintStep.ready || document == null || preview == null) {
      return;
    }
    emit(state._with(step: PrintStep.printing));

    final choices = state.choices;
    final Job job;
    try {
      job =
          await _tryAgain(document, choices) ??
          await _jobsRepository.startPrint(
            organizationId: _organizationId,
            printerId: _printer.id,
            title: document.name,
            choices: choices,
            pageCount: preview.pageCount,
            connectionId: _printer.connections.firstOrNull?.id,
          );
    } on ApiException catch (error) {
      emit(state._with(step: PrintStep.ready, error: error));
      return;
    }

    final print = await _printersRepository.print(
      organizationId: _organizationId,
      printer: _printer,
      document: PrintDocument(
        name: document.name,
        mimeType: document.mimeType!,
        length: document.length,
        open: document.open,
        pageCount: preview.pageCount,
        rasterise: (page) => _documents.renderer.rasterise(document, page),
      ),
      request: PrintRequest(
        copies: choices.copies,
        sides: choices.sides,
        color: choices.color,
        media: choices.mediaSize,
        tray: choices.tray,
        mediaType: choices.mediaType,
        quality: choices.quality,
        pageRanges: choices.pageRanges,
        orientation: choices.orientation,
        collate: choices.collate,
      ),
      // Short enough to sit beside the name on the printer's panel.
      reference: job.id.substring(0, 8),
    );
    _print = print;

    // The record is kept in order, but the screen does not wait on it: a
    // slow API must not hold back what the printer is doing.
    var records = Future<void>.value();
    String? recorded;
    PrintProgress? last;
    await for (final progress in print.progress) {
      last = progress;
      if (!isClosed) emit(state._with(progress: progress));

      final update = _record(progress, print, preview.pageCount);
      // Each connection tried is recorded; a repeat of the same is not.
      final key = '${update?.status} ${update?.connectionId}';
      if (update != null && key != recorded) {
        recorded = key;
        records = records.then(
          (_) => _jobsRepository.report(_organizationId, job.id, update),
        );
      }
    }
    await records;
    _print = null;
    _retry = switch (last?.stage) {
      PrintStage.failed || PrintStage.unknown || PrintStage.cancelled => (
        jobId: job.id,
        title: document.name,
        choices: choices,
      ),
      _ => null,
    };
    if (!isClosed) {
      emit(state._with(step: PrintStep.finished, progress: last));
    }
  }

  /// Records this print as another try of the one that failed, when it is
  /// the same document printed the same way. Null when it is not, or when
  /// the backend cannot record it so: it is then a job of its own.
  Future<Job?> _tryAgain(PickedDocument document, PrintChoices choices) async {
    final retry = _retry;
    if (retry == null ||
        retry.title != document.name ||
        retry.choices != choices) {
      return null;
    }
    try {
      return await _jobsRepository.retry(
        organizationId: _organizationId,
        jobId: retry.jobId,
      );
    } on ApiException {
      return null;
    }
  }

  /// Stops the print, on the printer when it already has the job.
  Future<void> cancel() async {
    await _print?.cancel();
  }

  /// Goes back to the document, to print it again or differently.
  void again() {
    if (state.step == PrintStep.finished) {
      emit(state._with(step: PrintStep.ready));
    }
  }

  /// Hands the document to the phone's own print dialog.
  Future<void> useSystemPrint() async {
    final document = state.document;
    if (!state.canUseSystemPrint || document == null) return;
    final sent = await _documents.renderer.systemPrint(document);
    if (!isClosed) {
      emit(state._with(progress: state.progress, handedToSystem: sent));
    }
  }

  /// What to tell the backend about a step, or null for a step that
  /// changes nothing in the job's record.
  static JobUpdate? _record(
    PrintProgress progress,
    PrinterPrint print,
    int pageCount,
  ) {
    final connectionId = print.connectionIdOf(progress.connection);
    return switch (progress.stage) {
      PrintStage.connecting => JobUpdate(
        status: 'processing',
        connectionId: connectionId,
      ),
      PrintStage.printing => JobUpdate(
        status: 'printing',
        connectionId: connectionId,
        printerJobRef: '${progress.printerJobId}',
      ),
      PrintStage.completed => JobUpdate(
        status: 'completed',
        connectionId: connectionId,
        pageCount: pageCount,
      ),
      PrintStage.cancelled => JobUpdate(
        status: 'cancelled',
        connectionId: connectionId,
      ),
      PrintStage.failed || PrintStage.unknown => JobUpdate(
        status: 'failed',
        connectionId: connectionId,
        errorCode: progress.errorCode,
        errorMessage: progress.errorMessage,
      ),
      PrintStage.preparing ||
      PrintStage.sending ||
      PrintStage.attention => null,
    };
  }
}
