import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';

/// How a document is to be printed. Anything left null is the printer's
/// own choice.
class PrintChoices extends Equatable {
  const new({
    this.copies = 1,
    this.color = 'auto',
    this.sides = 'one_sided',
    this.mediaSize,
    this.mediaType,
    this.tray,
    this.quality,
    this.pageRanges,
    this.orientation = 'auto',
    this.collate = true,
  });

  factory fromJson(Map<String, dynamic> json) {
    return PrintChoices(
      copies: json['copies'] as int? ?? 1,
      color: json['color_mode'] as String? ?? 'auto',
      sides: json['duplex'] as String? ?? 'one_sided',
      mediaSize: json['media_size'] as String?,
      mediaType: json['media_type'] as String?,
      tray: json['tray'] as String?,
      quality: json['quality'] as String?,
      pageRanges: json['page_ranges'] as String?,
      orientation: json['orientation'] as String? ?? 'auto',
      collate: json['collate'] as bool? ?? true,
    );
  }

  final int copies;

  /// `auto`, `color`, or `monochrome`.
  final String color;

  /// `one_sided`, `two_sided_long_edge`, or `two_sided_short_edge`.
  final String sides;

  /// A PWG media name, such as `iso_a4_210x297mm`.
  final String? mediaSize;
  final String? mediaType;
  final String? tray;

  /// `draft`, `normal`, or `high`.
  final String? quality;

  /// Such as `1-3,5`. Null prints every page.
  final String? pageRanges;

  /// `auto`, `portrait`, or `landscape`.
  final String orientation;
  final bool collate;

  bool get twoSided => sides != 'one_sided';

  PrintChoices copyWith({
    int? copies,
    String? color,
    String? sides,
    String? Function()? mediaSize,
    String? Function()? tray,
    String? Function()? quality,
    String? Function()? pageRanges,
    String? orientation,
    bool? collate,
  }) {
    return PrintChoices(
      copies: copies ?? this.copies,
      color: color ?? this.color,
      sides: sides ?? this.sides,
      mediaSize: mediaSize == null ? this.mediaSize : mediaSize(),
      mediaType: mediaType,
      tray: tray == null ? this.tray : tray(),
      quality: quality == null ? this.quality : quality(),
      pageRanges: pageRanges == null ? this.pageRanges : pageRanges(),
      orientation: orientation ?? this.orientation,
      collate: collate ?? this.collate,
    );
  }

  /// The settings as the API records them.
  PrintSettingsInput toApi() {
    return PrintSettingsInput(
      copies: copies,
      colorMode: PrintSettingsInputColorMode.fromJson(color),
      duplex: DuplexMode.fromJson(sides),
      mediaSize: mediaSize,
      mediaType: mediaType,
      tray: tray,
      quality: quality,
      pageRanges: pageRanges,
      orientation: PrintSettingsInputOrientation.fromJson(orientation),
      collate: collate,
    );
  }

  @override
  List<Object?> get props => [
    copies,
    color,
    sides,
    mediaSize,
    mediaType,
    tray,
    quality,
    pageRanges,
    orientation,
    collate,
  ];
}

/// A print, scan, or copy job and where it has got to.
class Job extends Equatable {
  const new({
    required this.id,
    required this.kind,
    required this.status,
    required this.printerId,
    required this.submittedAt,
    this.title,
    this.pageCount,
    this.connectionType,
    this.fallbackOccurred = false,
    this.errorCode,
    this.errorMessage,
    this.completedAt,
    this.print,
    this.waitingToSync = false,
  });

  /// A job as the API returns it, or as it was sent to the API.
  factory fromJson(Map<String, dynamic> json, {bool waitingToSync = false}) {
    final kind = json['type'] as String? ?? 'print';
    final settings = json['settings'];
    final submitted = json['submitted_at'] as String?;
    final completed = json['completed_at'] as String?;
    return Job(
      id: json['id'] as String,
      kind: kind,
      status: json['status'] as String? ?? 'queued',
      printerId: json['printer_id'] as String,
      submittedAt: submitted == null
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.parse(submitted),
      title: json['title'] as String?,
      pageCount: json['page_count'] as int?,
      connectionType: json['connection_type'] as String?,
      fallbackOccurred: json['fallback_occurred'] as bool? ?? false,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      completedAt: completed == null ? null : DateTime.parse(completed),
      print: kind == 'print' && settings is Map<String, dynamic>
          ? PrintChoices.fromJson(settings)
          : null,
      waitingToSync: waitingToSync,
    );
  }

  factory fromApi(JobRead job) => Job.fromJson(job.toJson());

  final String id;

  /// `print`, `scan`, or `copy`.
  final String kind;

  /// `queued`, `processing`, `scanning`, `printing`, `completed`,
  /// `failed`, or `cancelled`.
  final String status;
  final String printerId;
  final DateTime submittedAt;
  final String? title;
  final int? pageCount;

  /// The kind of connection the job last used, such as `ipp`.
  final String? connectionType;

  /// True when the job moved to another connection after its first try.
  final bool fallbackOccurred;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? completedAt;

  /// How it was to be printed. Null for a scan or a copy.
  final PrintChoices? print;

  /// True for a job the backend has not been told about yet.
  final bool waitingToSync;

  static const Set<String> _finished = {'completed', 'failed', 'cancelled'};

  /// True once the job will not change again.
  bool get isFinished => _finished.contains(status);

  /// True when the job can be run again as a new job.
  bool get canRetry => status == 'failed' || status == 'cancelled';

  @override
  List<Object?> get props => [
    id,
    kind,
    status,
    printerId,
    submittedAt,
    title,
    pageCount,
    connectionType,
    fallbackOccurred,
    errorCode,
    errorMessage,
    completedAt,
    print,
    waitingToSync,
  ];
}

/// One step in a job's history.
class JobEvent extends Equatable {
  const new({
    required this.status,
    required this.occurredAt,
    this.connectionType,
    this.errorCode,
    this.errorMessage,
  });

  factory fromApi(JobEventRead event) {
    return JobEvent(
      status: event.status.json ?? 'queued',
      occurredAt: event.occurredAt,
      connectionType: event.connectionType,
      errorCode: event.errorCode,
      errorMessage: event.errorMessage,
    );
  }

  final String status;
  final DateTime occurredAt;
  final String? connectionType;
  final String? errorCode;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    status,
    occurredAt,
    connectionType,
    errorCode,
    errorMessage,
  ];
}

/// A change in a running job, as the phone saw it.
class JobUpdate extends Equatable {
  const new({
    required this.status,
    this.connectionId,
    this.errorCode,
    this.errorMessage,
    this.printerJobRef,
    this.pageCount,
  });

  final String status;

  /// The connection this attempt used.
  final String? connectionId;

  /// Such as `ipp.client-error-not-possible`.
  final String? errorCode;
  final String? errorMessage;

  /// The printer's own name for the job.
  final String? printerJobRef;
  final int? pageCount;

  JobEventCreate toApi(DateTime occurredAt) {
    return JobEventCreate(
      status: JobStatus.fromJson(status),
      connectionId: connectionId,
      occurredAt: occurredAt,
      errorCode: errorCode,
      errorMessage: errorMessage == null || errorMessage!.length <= 500
          ? errorMessage
          : errorMessage!.substring(0, 500),
      printerJobRef: printerJobRef,
      pageCount: pageCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    connectionId,
    errorCode,
    errorMessage,
    printerJobRef,
    pageCount,
  ];
}
