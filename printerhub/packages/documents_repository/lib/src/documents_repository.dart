import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:documents_repository/src/file_transfer.dart';
import 'package:documents_repository/src/stored_document.dart';

/// A document's record was made, but its file did not reach the storage.
/// Give [document] to `DocumentsRepository.finish` to send the file again.
class UploadInterrupted implements Exception {
  const new(this.document, this.cause);

  final StoredDocument document;
  final Object cause;

  @override
  String toString() => 'UploadInterrupted(${document.id}, $cause)';
}

/// The documents a workspace keeps, and the files behind them.
///
/// A file goes straight from the phone to the workspace's storage, and
/// back, over a link the API signs: the API itself never carries it.
class DocumentsRepository {
  new({required this._client, required this._transfer, Directory? directory})
    : _directory = directory ?? Directory.systemTemp;

  final PrinterHubClient _client;
  final FileTransfer _transfer;
  final Directory _directory;

  /// Puts [file] in the workspace, and returns its record. It is its
  /// owner's alone unless [shared].
  ///
  /// [text] is what the document says, read on the phone. [id] is the
  /// identifier to record it under, for a document the phone already
  /// knows by one; make it with `newRecordId`.
  ///
  /// Throws an [ApiException] when the record cannot be made, which is
  /// also how a workspace that keeps documents on devices only says so,
  /// and [UploadInterrupted] when it was made but the file did not arrive.
  Future<StoredDocument> keep({
    required String organizationId,
    required File file,
    required String name,
    required String mimeType,
    int? pageCount,
    String source = 'printer_scan',
    String? printerId,
    String? text,
    String? id,
    bool shared = false,
  }) async {
    final size = await file.length();
    final created = await apiCall(
      () => _client.api.documents.createDocument(
        orgId: organizationId,
        idempotencyKey: newIdempotencyKey(),
        body: DocumentCreate(
          // The documents are listed by identifier, newest first.
          id: id ?? newRecordId(),
          fileName: name,
          mimeType: mimeType,
          sizeBytes: size,
          pageCount: pageCount,
          source: DocumentSource.fromJson(source),
          storageMode: StorageMode.cloud,
          sourcePrinterId: printerId,
          shared: shared,
          // The words in it, when the phone has read them: the workspace
          // can then find the document by what it says.
          ocrText: text == null || text.trim().isEmpty ? null : text,
        ),
      ),
    );
    return await _send(
      organizationId,
      // What was created is a document's record with the upload beside it.
      StoredDocument.fromApi(DocumentRead.fromJson(created.toJson())),
      file,
      created.upload,
    );
  }

  /// Sends the file of a document whose first upload did not finish.
  Future<StoredDocument> finish({
    required String organizationId,
    required StoredDocument document,
    required File file,
  }) {
    return _send(organizationId, document, file, null);
  }

  Future<StoredDocument> _send(
    String organizationId,
    StoredDocument document,
    File file,
    UploadInstructions? given,
  ) async {
    try {
      final upload =
          given ??
          await apiCall<UploadInstructions>(
            () => _client.api.documents.getUploadUrl(
              orgId: organizationId,
              documentId: document.id,
            ),
          );
      await _transfer.upload(
        Uri.parse(upload.url),
        file: file,
        method: upload.method,
        headers: upload.headers,
      );
      return StoredDocument.fromApi(
        await apiCall(
          () => _client.api.documents.completeUpload(
            orgId: organizationId,
            documentId: document.id,
          ),
        ),
      );
    } on Exception catch (error) {
      throw UploadInterrupted(document, error);
    }
  }

  /// A page of the workspace's documents, newest first. [query] matches a
  /// name, a tag, or text recognised in the document. Pass [cursor] from
  /// the page before to read on.
  Future<({List<StoredDocument> documents, String? next})> list({
    required String organizationId,
    String? query,
    String? cursor,
  }) async {
    final wanted = query?.trim() ?? '';
    final page = await apiCall(
      () => _client.api.documents.listDocuments(
        orgId: organizationId,
        q: wanted.isEmpty ? null : wanted,
        cursor: cursor,
      ),
    );
    return (
      documents: page.items.map(StoredDocument.fromApi).toList(),
      next: page.nextCursor,
    );
  }

  Future<StoredDocument> get({
    required String organizationId,
    required String documentId,
  }) async {
    return StoredDocument.fromApi(
      await apiCall(
        () => _client.api.documents.getDocument(
          orgId: organizationId,
          documentId: documentId,
        ),
      ),
    );
  }

  Future<StoredDocument> rename({
    required String organizationId,
    required String documentId,
    required String name,
  }) async {
    return StoredDocument.fromApi(
      await apiCall(
        () => _client.api.documents.updateDocument(
          orgId: organizationId,
          documentId: documentId,
          body: DocumentUpdate(fileName: name),
        ),
      ),
    );
  }

  /// Lets every member of the workspace see the document, or, with
  /// [shared] false, keeps it to its owner again.
  Future<StoredDocument> share({
    required String organizationId,
    required String documentId,
    required bool shared,
  }) async {
    return StoredDocument.fromApi(
      await apiCall(
        () => _client.api.documents.updateDocument(
          orgId: organizationId,
          documentId: documentId,
          body: DocumentUpdate(shared: shared),
        ),
      ),
    );
  }

  /// Deletes the document and its file from the workspace.
  Future<void> delete({
    required String organizationId,
    required String documentId,
  }) {
    return apiCall(
      () => _client.api.documents.deleteDocument(
        orgId: organizationId,
        documentId: documentId,
      ),
    );
  }

  /// Fetches a document's file onto the phone, and returns it.
  ///
  /// Throws an [ApiException] when the workspace has no file for it and
  /// [TransferFailed] when the file cannot be fetched.
  Future<File> fetch({
    required String organizationId,
    required StoredDocument document,
  }) async {
    final link = await apiCall(
      () => _client.api.documents.getDownloadUrl(
        orgId: organizationId,
        documentId: document.id,
      ),
    );
    // Under the document's own identifier, so two of a name do not meet.
    final folder = Directory('${_directory.path}/${document.id}');
    await folder.create(recursive: true);
    final file = File(
      '${folder.path}/${document.name.replaceAll(RegExp(r'[\\/]'), '-')}',
    );
    await _transfer.download(Uri.parse(link.url), into: file);
    return file;
  }
}
