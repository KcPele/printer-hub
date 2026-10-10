import 'package:documents_repository/documents_repository.dart';
import 'package:equatable/equatable.dart';

/// How far something made on this phone has got towards the account.
enum LibraryStanding {
  /// On this phone only, so far.
  waiting,

  /// The account knows of it, but its file has not arrived.
  recorded,

  /// In the account: the person's other devices have it too.
  synced,
}

/// Something made on this phone and kept: a scan, a page a tool made, a
/// sheet of photos. Its file stays on the phone, where it can be opened
/// with no network, and a copy goes to the person's account.
class LibraryItem extends Equatable {
  const new({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    this.pageCount,
    this.source = 'upload',
    this.printerId,
    this.text,
    this.standing = LibraryStanding.waiting,
    this.refused = false,
  });

  factory fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      pageCount: json['page_count'] as int?,
      source: json['source'] as String,
      printerId: json['printer_id'] as String?,
      text: json['text'] as String?,
      standing: LibraryStanding.values.byName(json['standing'] as String),
      refused: json['refused'] as bool,
    );
  }

  /// Its identifier, here and in the account: the same one, so that the
  /// two are known to be the same document.
  final String id;

  /// The workspace it was made in.
  final String organizationId;

  /// Its file name, such as `Receipts.pdf`.
  final String name;

  /// Where its file is on this phone.
  final String path;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
  final int? pageCount;

  /// Where it came from: `printer_scan`, `camera_scan`, or `upload`.
  final String source;

  /// The printer it was scanned on.
  final String? printerId;

  /// What it says, when the phone has read it.
  final String? text;
  final LibraryStanding standing;

  /// True when the workspace would not take it: one that keeps documents
  /// on devices only, for one.
  final bool refused;

  /// True when the account has it.
  bool get synced => standing == LibraryStanding.synced;

  LibraryItem copyWith({
    String? name,
    String? path,
    LibraryStanding? standing,
    bool? refused,
  }) {
    return LibraryItem(
      id: id,
      organizationId: organizationId,
      name: name ?? this.name,
      path: path ?? this.path,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      pageCount: pageCount,
      source: source,
      printerId: printerId,
      text: text,
      standing: standing ?? this.standing,
      refused: refused ?? this.refused,
    );
  }

  /// This, as a document is listed. One the account does not have yet is
  /// not in its storage.
  StoredDocument get asDocument => StoredDocument(
    id: id,
    name: name,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    createdAt: createdAt,
    pageCount: pageCount,
    source: source,
    inCloud: standing != LibraryStanding.waiting,
    uploaded: synced,
    printerId: printerId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'name': name,
    'path': path,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'created_at': createdAt.toUtc().toIso8601String(),
    'page_count': pageCount,
    'source': source,
    'printer_id': printerId,
    'text': text,
    'standing': standing.name,
    'refused': refused,
  };

  @override
  List<Object?> get props => [
    id,
    organizationId,
    name,
    path,
    mimeType,
    sizeBytes,
    createdAt,
    pageCount,
    source,
    printerId,
    text,
    standing,
    refused,
  ];
}
