import 'package:meta/meta.dart';
import 'package:printer_protocols/src/ipp/ipp_constants.dart';
import 'package:printer_protocols/src/ipp/ipp_message.dart';
import 'package:printer_protocols/src/ipp/pwg_media.dart';
import 'package:printer_protocols/src/raster/raster_encoder.dart';

/// What the printer as a whole is doing.
enum IppPrinterState {
  idle,
  processing,
  stopped,
  unknown;

  static IppPrinterState fromCode(Object? code) => switch (code) {
    3 => idle,
    4 => processing,
    5 => stopped,
    _ => unknown,
  };
}

/// Where a print job is in its life.
enum IppJobState {
  pending,
  pendingHeld,
  processing,
  processingStopped,
  canceled,
  aborted,
  completed,
  unknown;

  static IppJobState fromCode(Object? code) => switch (code) {
    3 => pending,
    4 => pendingHeld,
    5 => processing,
    6 => processingStopped,
    7 => canceled,
    8 => aborted,
    9 => completed,
    _ => unknown,
  };

  /// True once the job will not change again.
  bool get isFinished =>
      this == canceled || this == aborted || this == completed;
}

/// A toner, ink, drum, or other supply the printer reports on.
@immutable
class IppMarker {
  const new({required this.name, this.type, this.color, this.levelPercent});

  final String name;

  /// Such as `toner`, `ink`, `opc`, `waste-toner`.
  final String? type;

  /// A colour name or `#RRGGBB`, as the printer gives it.
  final String? color;

  /// 0 to 100, or null when the printer does not know.
  final int? levelPercent;
}

/// The printer's answer to Get-Printer-Attributes, with the attributes the
/// app uses as typed getters. Anything else is in [group].
@immutable
class IppPrinterAttributes {
  const new(this.group);

  final IppGroup group;

  String? _text(String name) {
    final value = group[name]?.first;
    return value is String && value.isNotEmpty ? value : null;
  }

  List<String> _texts(String name) => group[name]?.strings ?? const [];

  String? get name => _text('printer-name');
  String? get info => _text('printer-info');
  String? get location => _text('printer-location');
  String? get makeAndModel => _text('printer-make-and-model');
  String? get deviceId => _text('printer-device-id');

  /// The `urn:uuid:` prefix is dropped.
  String? get uuid => _text('printer-uuid')?.replaceFirst('urn:uuid:', '');

  /// The printer's own web page.
  String? get moreInfo => _text('printer-more-info');

  IppPrinterState get state =>
      IppPrinterState.fromCode(group['printer-state']?.first);

  /// Why the printer is in its state, without the `none` placeholder: for
  /// example `media-jam-error`, `toner-low-warning`, `door-open-error`.
  List<String> get stateReasons => [
    for (final reason in _texts('printer-state-reasons'))
      if (reason != 'none') reason,
  ];

  /// Null when the printer does not say.
  bool? get isAcceptingJobs {
    final value = group['printer-is-accepting-jobs']?.first;
    return value is bool ? value : null;
  }

  int? get queuedJobCount {
    final value = group['queued-job-count']?.first;
    return value is int ? value : null;
  }

  List<String> get documentFormats => _texts('document-format-supported');
  String? get defaultDocumentFormat => _text('document-format-default');

  /// True when the printer says so, or lists a colour mode.
  bool get colorSupported {
    final value = group['color-supported']?.first;
    if (value is bool) return value;
    return colorModes.contains('color');
  }

  /// Such as `auto`, `color`, `monochrome`.
  List<String> get colorModes => _texts('print-color-mode-supported');

  /// Such as `one-sided`, `two-sided-long-edge`.
  List<String> get sides => _texts('sides-supported');

  /// PWG media names, such as `iso_a4_210x297mm`.
  List<String> get media => _texts('media-supported');
  String? get defaultMedia => _text('media-default');
  List<String> get mediaTypes => _texts('media-type-supported');

  /// Trays, such as `tray-1`, `by-pass-tray`. `auto` is the printer's
  /// choice, not a tray.
  List<String> get mediaSources => _texts('media-source-supported');

  /// The most copies one job may ask for, or null when not stated.
  int? get maxCopies {
    final value = group['copies-supported']?.first;
    return value is IppRange ? value.upper : null;
  }

  /// Distinct resolutions in dots per inch, ascending.
  List<int> get resolutionsDpi {
    final values = group['printer-resolution-supported']?.values ?? const [];
    final found = <int>{
      for (final item in values)
        if (item.value is IppResolution) (item.value! as IppResolution).dpi,
    };
    return found.toList()..sort();
  }

  /// `draft`, `normal`, and `high`, as far as the printer offers them.
  List<String> get qualities => [
    for (final code
        in group['print-quality-supported']?.integers ?? const <int>[])
      ?switch (code) {
        3 => 'draft',
        4 => 'normal',
        5 => 'high',
        _ => null,
      },
  ];

  /// Finishing codes other than 3, which means "none".
  List<int> get finishings => [
    for (final code in group['finishings-supported']?.integers ?? const <int>[])
      if (code != 3) code,
  ];

  /// True when the printer can collate copies.
  bool get collationSupported {
    return _texts('multiple-document-handling-supported')
        .any((value) => value.contains('collated'));
  }

  List<String> get ippVersions => _texts('ipp-versions-supported');
  List<int> get operations =>
      group['operations-supported']?.integers ?? const [];

  /// True when the printer takes URF, the raster format AirPrint uses.
  bool get supportsAirPrint =>
      group['urf-supported'] != null || documentFormats.contains('image/urf');

  /// What the printer says about the Apple Raster it takes.
  UrfSupport get urf => UrfSupport.parse(_texts('urf-supported'));

  /// The pixel layouts the printer takes in PWG Raster, such as `srgb_8`
  /// and `sgray_8`.
  List<String> get pwgRasterTypes =>
      _texts('pwg-raster-document-type-supported');

  /// The resolutions the printer takes PWG Raster at, ascending. Only those
  /// that are the same across and down.
  List<int> get pwgRasterResolutionsDpi {
    final values =
        group['pwg-raster-document-resolution-supported']?.values ?? const [];
    final found = <int>{
      for (final item in values)
        if (item.value case final IppResolution resolution)
          if (resolution.x == resolution.y) resolution.dpi,
    };
    return found.toList()..sort();
  }

  /// How the back of a sheet is delivered in PWG Raster.
  SheetBack get pwgRasterSheetBack =>
      SheetBack.fromKeyword(_text('pwg-raster-document-sheet-back'));

  /// How the printer checks who is printing, one entry per address it
  /// listens on: `none`, `basic`, `digest`, `requesting-user-name`.
  List<String> get authenticationSchemes =>
      _texts('uri-authentication-supported');

  /// True when the printer wants a user name and password.
  bool get requiresAuthentication => authenticationSchemes.any(
    (scheme) => scheme == 'basic' || scheme == 'digest',
  );

  /// The members of `media-col` the printer reads, such as `media-size`,
  /// `media-source`, `media-type`.
  List<String> get mediaColMembers => _texts('media-col-supported');

  /// The job attributes the printer acts on. Empty when it does not say.
  List<String> get jobCreationAttributes =>
      _texts('job-creation-attributes-supported');

  /// Supplies, matched up across the four `marker-*` attributes.
  List<IppMarker> get markers {
    final names = _texts('marker-names');
    final types = _texts('marker-types');
    final colors = _texts('marker-colors');
    final levels = group['marker-levels']?.integers ?? const <int>[];
    return [
      for (var i = 0; i < names.length; i++)
        IppMarker(
          name: names[i],
          type: i < types.length ? types[i] : null,
          color: i < colors.length ? colors[i] : null,
          // Negative levels are IPP's way of saying "unknown".
          levelPercent: i < levels.length && levels[i] >= 0 ? levels[i] : null,
        ),
    ];
  }
}

/// What a printer's `urf-supported` says about the Apple Raster it takes.
///
/// The values are short codes: `W8` for grey, `SRGB24` for colour,
/// `RS300-600` for resolutions, `DM1` to `DM4` for how the back of a sheet
/// is delivered.
@immutable
class UrfSupport {
  const new({
    this.color = false,
    this.resolutionsDpi = const [300],
    this.sheetBack = SheetBack.normal,
  });

  factory parse(List<String> codes) {
    var color = false;
    var resolutions = const <int>[300];
    var sheetBack = SheetBack.normal;
    for (final code in codes.map((code) => code.toUpperCase())) {
      if (code == 'SRGB24') color = true;
      if (code.startsWith('RS')) {
        final found = [
          for (final part in code.substring(2).split('-')) ?int.tryParse(part),
        ]..sort();
        if (found.isNotEmpty) resolutions = found;
      }
      sheetBack = switch (code) {
        'DM2' => SheetBack.flipped,
        'DM3' => SheetBack.rotated,
        'DM4' => SheetBack.manualTumble,
        _ => sheetBack,
      };
    }
    return UrfSupport(
      color: color,
      resolutionsDpi: resolutions,
      sheetBack: sheetBack,
    );
  }

  /// True when the printer takes colour. Every AirPrint printer takes grey.
  final bool color;
  final List<int> resolutionsDpi;
  final SheetBack sheetBack;
}

/// A print job as the printer reports it.
@immutable
class IppJob {
  const new({
    required this.id,
    required this.state,
    this.uri,
    this.stateReasons = const [],
    this.name,
  });

  factory fromGroup(IppGroup group) {
    final id = group['job-id']?.first;
    final uri = group['job-uri']?.first;
    final name = group['job-name']?.first;
    return IppJob(
      id: id is int ? id : 0,
      uri: uri is String ? uri : null,
      state: IppJobState.fromCode(group['job-state']?.first),
      stateReasons: [
        for (final reason
            in group['job-state-reasons']?.strings ?? const <String>[])
          if (reason != 'none') reason,
      ],
      name: name is String ? name : null,
    );
  }

  final int id;
  final String? uri;
  final IppJobState state;

  /// Such as `job-printing`, `media-jam-error`, `job-canceled-by-user`.
  final List<String> stateReasons;
  final String? name;
}

/// How a document should be printed. Anything left null is the printer's
/// default.
@immutable
class IppJobOptions {
  const new({
    this.jobName,
    this.documentFormat = 'application/pdf',
    this.copies,
    this.sides,
    this.colorMode,
    this.media,
    this.mediaSource,
    this.mediaType,
    this.quality,
    this.orientation,
    this.pageRanges,
    this.collate,
    this.scaling,
  });

  final String? jobName;
  final String documentFormat;
  final int? copies;

  /// `one-sided`, `two-sided-long-edge`, or `two-sided-short-edge`.
  final String? sides;

  /// `auto`, `color`, or `monochrome`.
  final String? colorMode;

  /// A PWG media name, such as `iso_a4_210x297mm`.
  final String? media;

  /// A tray, such as `tray-1`.
  final String? mediaSource;
  final String? mediaType;

  /// `draft`, `normal`, or `high`.
  final String? quality;

  /// `portrait` or `landscape`.
  final String? orientation;
  final List<IppRange>? pageRanges;
  final bool? collate;

  /// `auto`, `fit`, `fill`, or `none`.
  final String? scaling;

  /// The job-template attributes for these options.
  List<IppAttribute> toJobAttributes() {
    IppAttribute keyword(String name, String value) {
      return IppAttribute.single(name, IppValueTag.keyword, value);
    }

    final qualityCode = switch (quality) {
      'draft' => 3,
      'normal' => 4,
      'high' => 5,
      _ => null,
    };
    final orientationCode = switch (orientation) {
      'portrait' => 3,
      'landscape' => 4,
      _ => null,
    };
    final ranges = pageRanges;
    final size = media == null ? null : PwgMedia.parse(media!);

    return [
      if (copies != null)
        IppAttribute.single('copies', IppValueTag.integer, copies),
      if (sides != null) keyword('sides', sides!),
      if (colorMode != null) keyword('print-color-mode', colorMode!),
      // A tray or a paper type can only be asked for inside `media-col`,
      // and a request carries `media` or `media-col`, never both.
      if (mediaSource != null || mediaType != null)
        IppAttribute.single('media-col', IppValueTag.beginCollection, {
          if (size != null)
            'media-size': IppAttribute.single(
              'media-size',
              IppValueTag.beginCollection,
              {
                'x-dimension': IppAttribute.single(
                  'x-dimension',
                  IppValueTag.integer,
                  size.widthHundredthsMm,
                ),
                'y-dimension': IppAttribute.single(
                  'y-dimension',
                  IppValueTag.integer,
                  size.heightHundredthsMm,
                ),
              },
            ),
          if (mediaSource != null)
            'media-source': keyword('media-source', mediaSource!),
          if (mediaType != null)
            'media-type': keyword('media-type', mediaType!),
        })
      else if (media != null)
        keyword('media', media!),
      if (qualityCode != null)
        IppAttribute.single(
          'print-quality',
          IppValueTag.enumeration,
          qualityCode,
        ),
      if (orientationCode != null)
        IppAttribute.single(
          'orientation-requested',
          IppValueTag.enumeration,
          orientationCode,
        ),
      if (ranges != null && ranges.isNotEmpty)
        IppAttribute.all('page-ranges', IppValueTag.rangeOfInteger, ranges),
      if (collate != null)
        keyword(
          'multiple-document-handling',
          collate!
              ? 'separate-documents-collated-copies'
              : 'separate-documents-uncollated-copies',
        ),
      if (scaling != null) keyword('print-scaling', scaling!),
    ];
  }
}
