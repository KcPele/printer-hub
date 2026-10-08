import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';

/// A document a workspace keeps.
class StoredDocument extends Equatable {
  const new({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    this.pageCount,
    this.source = 'upload',
    this.inCloud = false,
    this.uploaded = false,
    this.printerId,
  });

  factory fromApi(DocumentRead document) {
    return StoredDocument(
      id: document.id,
      name: document.fileName,
      mimeType: document.mimeType,
      sizeBytes: document.sizeBytes,
      createdAt: document.createdAt,
      pageCount: document.pageCount,
      source: document.source.json ?? 'upload',
      inCloud: document.storageMode == StorageMode.cloud,
      uploaded: document.uploadStatus == UploadStatus.uploaded,
      printerId: document.sourcePrinterId,
    );
  }

  final String id;

  /// Its file name, such as `Receipts.pdf`.
  final String name;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
  final int? pageCount;

  /// Where it came from: `printer_scan`, `camera_scan`, or `upload`.
  final String source;

  /// True when its file is kept in the workspace's storage. Otherwise only
  /// the phone that made it has the file.
  final bool inCloud;

  /// True once the file has arrived in the storage.
  final bool uploaded;

  /// The printer it was scanned on.
  final String? printerId;

  /// True when the file can be fetched from the workspace.
  bool get canFetch => inCloud && uploaded;

  /// True when the record was made but the file never arrived.
  bool get awaitsFile => inCloud && !uploaded;

  @override
  List<Object?> get props => [
    id,
    name,
    mimeType,
    sizeBytes,
    createdAt,
    pageCount,
    source,
    inCloud,
    uploaded,
    printerId,
  ];
}
