import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:connection_engine/src/device.dart';
import 'package:equatable/equatable.dart';
import 'package:printer_protocols/printer_protocols.dart';

/// What is to be printed.
class PrintDocument {
  const new({
    required this.name,
    required this.mimeType,
    required this.length,
    required this.open,
    this.pageCount,
    this.rasterise,
  });

  /// Shown on the printer's panel and in its job log.
  final String name;

  /// What the file is: `application/pdf`, `image/jpeg`.
  final String mimeType;

  /// The size of the file in bytes.
  final int length;

  /// Opens the file for reading. Called again for each attempt.
  final Stream<List<int>> Function() open;

  /// How many pages it has, when that is known.
  final int? pageCount;

  /// Draws each page as pixels, in order, for a printer that does not read
  /// the file itself: [RasterDocument.bytesPerPage] bytes a page, as
  /// `rasterPageFromRgba` makes them. Null when the pages cannot be drawn.
  final Stream<Uint8List> Function(RasterDocument document)? rasterise;
}

/// How it is to be printed. Anything left null is the printer's choice.
class PrintRequest extends Equatable {
  const new({
    this.copies = 1,
    this.sides = 'one_sided',
    this.color = 'auto',
    this.media,
    this.tray,
    this.mediaType,
    this.quality,
    this.pageRanges,
    this.orientation = 'auto',
    this.collate = true,
  });

  final int copies;

  /// `one_sided`, `two_sided_long_edge`, or `two_sided_short_edge`.
  final String sides;

  /// `auto`, `color`, or `monochrome`.
  final String color;

  /// A PWG media name, such as `iso_a4_210x297mm`.
  final String? media;
  final String? tray;
  final String? mediaType;

  /// `draft`, `normal`, or `high`.
  final String? quality;

  /// Such as `1-3,5`.
  final String? pageRanges;

  /// `auto`, `portrait`, or `landscape`.
  final String orientation;
  final bool collate;

  @override
  List<Object?> get props => [
    copies,
    sides,
    color,
    media,
    tray,
    mediaType,
    quality,
    pageRanges,
    orientation,
    collate,
  ];
}

enum PrintStage {
  /// Asking a connection what the printer takes.
  connecting,

  /// Getting the document into a form the printer takes.
  preparing,

  /// The document is on its way to the printer.
  sending,

  /// The printer has the job.
  printing,

  /// The printer has stopped and wants something: paper, a closed door.
  attention,

  completed,
  failed,
  cancelled,

  /// The connection dropped as the document went, and the printer cannot
  /// be asked whether it arrived. Sending again could print it twice, so
  /// the person decides.
  unknown,
}

/// Where a print has got to.
class PrintProgress extends Equatable {
  const new(
    this.stage, {
    this.connection,
    this.printerJobId,
    this.errorCode,
    this.errorMessage,
    this.reasons = const [],
    this.fellBack = false,
  });

  final PrintStage stage;

  /// The connection in use.
  final DeviceConnection? connection;

  /// The printer's own number for the job, once it has one.
  final int? printerJobId;

  /// Why it failed: `print.unreachable`, `print.format_not_supported`,
  /// `ipp.client-error-not-possible`.
  final String? errorCode;

  /// What the printer said about it, when it said anything.
  final String? errorMessage;

  /// What the printer wants attention for, such as `media-jam-error`.
  final List<String> reasons;

  /// True once the print has moved to another connection.
  final bool fellBack;

  /// True when nothing more will follow.
  bool get isFinal =>
      stage == PrintStage.completed ||
      stage == PrintStage.failed ||
      stage == PrintStage.cancelled ||
      stage == PrintStage.unknown;

  @override
  List<Object?> get props => [
    stage,
    connection,
    printerJobId,
    errorCode,
    errorMessage,
    reasons,
    fellBack,
  ];
}

/// Prints documents on a printer the app has saved.
///
/// It asks the printer what it takes and sends the file as it is or as
/// pictures of its pages. The printer's connections are tried in order. It
/// moves to the next only when it is certain the document did not arrive,
/// so a fallback never prints twice.
class PrintRunner {
  new({
    required this._http,
    Directory? spoolDirectory,
    this.pollInterval = const Duration(seconds: 1),
    this.watchFor = const Duration(minutes: 10),
    Future<void> Function(Duration)? pause,
  }) : _spoolDirectory = spoolDirectory ?? Directory.systemTemp,
       _pause = pause ?? Future<void>.delayed;

  final PrinterHttp _http;
  final Directory _spoolDirectory;
  final Future<void> Function(Duration) _pause;

  /// How often the printer is asked how the job is going.
  final Duration pollInterval;

  /// How long a job is followed. After that it is left as printing: the
  /// printer has it, and may be waiting for paper.
  final Duration watchFor;

  /// Starts printing [document]. [reference] is a short code unique to
  /// this print; it is added to the job's name so the job can be found on
  /// the printer again if the connection drops.
  PrintRun start({
    required List<DeviceConnection> connections,
    required PrintDocument document,
    required PrintRequest request,
    required String reference,
    PrinterCredentials? credentials,
  }) {
    return PrintRun._(
      this,
      [
        for (final connection in connections)
          if (connection.type != 'escl') connection,
      ],
      document,
      request,
      '${document.name} [$reference]',
      credentials,
    ).._begin();
  }
}

/// One print in progress.
class PrintRun {
  new _(
    this._runner,
    this._connections,
    this._document,
    this._request,
    this._jobName,
    this._credentials,
  );

  final PrintRunner _runner;
  final List<DeviceConnection> _connections;
  final PrintDocument _document;
  final PrintRequest _request;
  final String _jobName;
  final PrinterCredentials? _credentials;

  final _progress = StreamController<PrintProgress>();
  bool _cancelled = false;
  bool _fellBack = false;
  DeviceConnection? _connection;
  IppClient? _client;
  int? _printerJobId;

  /// Each step of the print, ending with one that [PrintProgress.isFinal].
  Stream<PrintProgress> get progress => _progress.stream;

  /// Stops the print: before the document is sent, or on the printer once
  /// it has the job.
  Future<void> cancel() async {
    _cancelled = true;
    final client = _client;
    final jobId = _printerJobId;
    if (client == null || jobId == null) return;
    try {
      await client.cancelJob(jobId);
    } on Object {
      // Already finished, or out of reach. Following the job shows which.
    }
  }

  void _begin() => unawaited(_run().whenComplete(_progress.close));

  void _emit(
    PrintStage stage, {
    String? errorCode,
    String? errorMessage,
    List<String> reasons = const [],
  }) {
    _progress.add(
      PrintProgress(
        stage,
        connection: _connection,
        printerJobId: _printerJobId,
        errorCode: errorCode,
        errorMessage: errorMessage,
        reasons: reasons,
        fellBack: _fellBack,
      ),
    );
  }

  Future<void> _run() async {
    var failure = const _Failure('print.no_connection');
    for (final connection in _connections) {
      if (_cancelled) return _emit(PrintStage.cancelled);
      _connection = connection;
      _emit(PrintStage.connecting);

      final next = await _attempt(connection);
      if (next == null) return;
      failure = next;
      _fellBack = true;
    }
    _emit(
      PrintStage.failed,
      errorCode: failure.code,
      errorMessage: failure.message,
    );
  }

  /// Tries one connection. Returns null when the print ended here, one way
  /// or another, and the reason when the next connection should be tried.
  Future<_Failure?> _attempt(DeviceConnection connection) async {
    final client = IppClient(
      printerUri: connection.uri,
      http: _runner._http,
      credentials: _credentials,
    );
    _client = client;
    File? spool;
    try {
      final printer = await client.getPrinterAttributes();
      final format = choosePrintFormat(
        printer,
        sourceType: _document.mimeType,
        color: _request.color != 'monochrome',
      );
      final pageCount = _document.pageCount;
      final rasterise = _document.rasterise;
      if (format == null ||
          (format is RasterTarget &&
              (rasterise == null || pageCount == null))) {
        // No other connection changes what the printer can read.
        _emit(PrintStage.failed, errorCode: 'print.format_not_supported');
        return null;
      }

      _emit(PrintStage.preparing);
      var open = _document.open;
      var length = _document.length;
      if (format is RasterTarget) {
        final file = await _spool(format, printer, rasterise!, pageCount!);
        spool = file;
        open = file.openRead;
        length = await file.length();
      }

      final options = _options(printer, format);
      await client.wouldAccept(options);
      if (_cancelled) {
        _emit(PrintStage.cancelled);
        return null;
      }

      _emit(PrintStage.sending);
      final IppJob job;
      try {
        job = await client.printJob(
          document: open(),
          length: length,
          options: options,
          preflight: false,
        );
      } on IppException {
        // The printer answered, to refuse: it made no job.
        rethrow;
      } on Object {
        // The connection dropped as the document went. Did it arrive?
        final found = await _findOnPrinter(client);
        if (!found.asked) {
          _emit(PrintStage.unknown, errorCode: 'print.outcome_unknown');
          return null;
        }
        if (found.job == null) {
          return const _Failure('print.connection_lost');
        }
        await _follow(client, found.job!);
        return null;
      }
      await _follow(client, job);
      return null;
    } on PrinterUnreachable {
      return const _Failure('print.unreachable');
    } on IppNotAvailable catch (error) {
      return _Failure(
        error.needsAuthentication
            ? 'print.needs_password'
            : 'print.not_available',
      );
    } on IppException catch (error) {
      final failure = _Failure('ipp.${error.statusName}', error.message);
      if (!error.isClientError) return failure;
      // The request itself was refused. It would be refused again.
      _emit(
        PrintStage.failed,
        errorCode: failure.code,
        errorMessage: failure.message,
      );
      return null;
    } finally {
      if (spool != null && spool.existsSync()) spool.deleteSync();
    }
  }

  /// Looks for this print among the printer's jobs, by its name.
  Future<({bool asked, IppJob? job})> _findOnPrinter(IppClient client) async {
    try {
      final jobs = [
        ...await client.getJobs(),
        ...await client.getJobs(completed: true),
      ];
      return (
        asked: true,
        job: jobs.where((job) => job.name == _jobName).firstOrNull,
      );
    } on Object {
      return (asked: false, job: null);
    }
  }

  /// Watches the job on the printer until it ends.
  Future<void> _follow(IppClient client, IppJob job) async {
    _printerJobId = job.id;
    _emit(PrintStage.printing);
    if (_cancelled) await cancel();

    var current = job;
    var stopped = false;
    var misses = 0;
    final clock = Stopwatch()..start();
    while (!current.state.isFinished) {
      // Left as printing: the printer has it.
      if (clock.elapsed >= _runner.watchFor || misses >= 5) return;
      await _runner._pause(_runner.pollInterval);
      try {
        current = await client.getJobAttributes(job.id);
        misses = 0;
      } on IppException catch (error) {
        // Some printers forget a job the moment it is done.
        if (error.statusCode == IppStatus.clientErrorNotFound) {
          return _emit(PrintStage.completed);
        }
        misses++;
        continue;
      } on Object {
        // Out of reach for now. The printer still has the job, so nothing
        // here may send it again.
        misses++;
        continue;
      }

      final nowStopped = current.state == IppJobState.processingStopped;
      if (nowStopped && !stopped) {
        _emit(PrintStage.attention, reasons: current.stateReasons);
      } else if (!nowStopped && stopped && !current.state.isFinished) {
        _emit(PrintStage.printing);
      }
      stopped = nowStopped;
    }

    if (current.state == IppJobState.completed) {
      _emit(PrintStage.completed);
    } else if (current.state == IppJobState.canceled) {
      _emit(PrintStage.cancelled);
    } else {
      _emit(
        PrintStage.failed,
        errorCode: 'ipp.job-aborted',
        errorMessage: current.stateReasons.join(', '),
        reasons: current.stateReasons,
      );
    }
  }

  /// Draws the pages and writes them to a file, so the printer can be told
  /// the size before any of it is sent.
  Future<File> _spool(
    RasterTarget target,
    IppPrinterAttributes printer,
    Stream<Uint8List> Function(RasterDocument) rasterise,
    int pageCount,
  ) async {
    final media =
        PwgMedia.parse(_request.media ?? printer.defaultMedia ?? '') ??
        const PwgMedia('iso_a4_210x297mm', 21000, 29700);
    final document = target.document(
      media: media,
      pageCount: pageCount,
      sides: switch (_sides(printer)) {
        'two-sided-long-edge' => RasterSides.twoSidedLongEdge,
        'two-sided-short-edge' => RasterSides.twoSidedShortEdge,
        _ => RasterSides.oneSided,
      },
      quality: switch (_request.quality) {
        'draft' => 3,
        'normal' => 4,
        'high' => 5,
        _ => null,
      },
    );
    final encoder = RasterEncoder(document);
    final safe = _jobName.hashCode.toUnsigned(32).toRadixString(16);
    final file = File(
      '${_runner._spoolDirectory.path}/printerhub-$safe.raster',
    );
    final sink = file.openWrite()..add(encoder.start());
    try {
      var index = 0;
      await for (final pixels in rasterise(document)) {
        sink.add(encoder.page(pixels, index: index++));
      }
    } finally {
      await sink.close();
    }
    return file;
  }

  /// The two-sided mode to ask for, when the printer has it.
  String? _sides(IppPrinterAttributes printer) {
    final wanted = _request.sides.replaceAll('_', '-');
    return printer.sides.contains(wanted) ? wanted : null;
  }

  /// The request in the printer's terms. A choice the printer does not
  /// offer is left out, and the printer uses its own.
  IppJobOptions _options(IppPrinterAttributes printer, PrintFormat format) {
    T? offered<T>(T? wanted, List<T> offers) {
      return wanted != null && offers.contains(wanted) ? wanted : null;
    }

    final max = printer.maxCopies;
    final copies =
        _request.copies > 1 && (max == null || _request.copies <= max)
        ? _request.copies
        : null;
    final inMediaCol =
        printer.mediaColMembers.isEmpty ||
        printer.mediaColMembers.contains('media-source');
    return IppJobOptions(
      jobName: _jobName,
      documentFormat: format.mimeType,
      copies: copies,
      sides: _sides(printer),
      colorMode: offered(
        _request.color == 'auto' ? null : _request.color,
        printer.colorModes,
      ),
      media: offered(_request.media, printer.media),
      mediaSource: inMediaCol
          ? offered(_request.tray, printer.mediaSources)
          : null,
      mediaType: inMediaCol
          ? offered(_request.mediaType, printer.mediaTypes)
          : null,
      quality: offered(_request.quality, printer.qualities),
      orientation: _request.orientation == 'auto' ? null : _request.orientation,
      pageRanges: _ranges(_request.pageRanges),
      // Collating only means something with more than one copy.
      collate: copies != null && printer.collationSupported
          ? _request.collate
          : null,
    );
  }

  /// `1-3,5` as IPP ranges. Null for no ranges, or ones that make no sense.
  static List<IppRange>? _ranges(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final ranges = <IppRange>[];
    for (final part in text.split(',')) {
      final ends = part.trim().split('-');
      final first = int.tryParse(ends.first.trim());
      final last = int.tryParse(ends.last.trim());
      if (first == null || last == null || first < 1 || last < first) {
        return null;
      }
      ranges.add(IppRange(first, last));
    }
    return ranges;
  }
}

class _Failure {
  const new(this.code, [this.message]);

  final String code;
  final String? message;
}
