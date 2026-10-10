// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/document_create.dart';
import '../models/document_created.dart';
import '../models/document_read.dart';
import '../models/document_source.dart';
import '../models/document_update.dart';
import '../models/download_link.dart';
import '../models/page_document_read.dart';
import '../models/upload_instructions.dart';

part 'documents_client.g.dart';

@RestApi()
abstract class DocumentsClient {
  factory DocumentsClient(Dio dio, {String? baseUrl}) = _DocumentsClient;

  /// List Documents.
  ///
  /// Documents, newest first: the caller's own, and those other members have shared.
  ///
  /// [q] - Matches file name, recognized text, or a tag.
  ///
  /// [cursor] - `next_cursor` from the previous page.
  @GET('/api/v1/organizations/{org_id}/documents')
  Future<PageDocumentRead> listDocuments({
    @Path('org_id') required String orgId,
    @Query('limit') int? limit = 50,
    @Query('q') String? q,
    @Query('tag') String? tag,
    @Query('mime_type') String? mimeType,
    @Query('source') DocumentSource? source,
    @Query('source_printer_id') String? sourcePrinterId,
    @Query('created_from') DateTime? createdFrom,
    @Query('created_to') DateTime? createdTo,
    @Query('cursor') String? cursor,
  });

  /// Create Document.
  ///
  /// Register a document.
  ///
  /// A `local` document records metadata only; its bytes stay on the device.
  /// A `cloud` document returns upload instructions: send the bytes to that.
  /// URL, then call `complete-upload`.
  @POST('/api/v1/organizations/{org_id}/documents')
  Future<DocumentCreated> createDocument({
    @Path('org_id') required String orgId,
    @Body() required DocumentCreate body,
    @Header('Idempotency-Key') String? idempotencyKey,
  });

  /// Delete Document.
  ///
  /// Delete the document and, for a cloud document, its stored file.
  @DELETE('/api/v1/organizations/{org_id}/documents/{document_id}')
  Future<void> deleteDocument({
    @Path('document_id') required String documentId,
    @Path('org_id') required String orgId,
  });

  /// Get Document
  @GET('/api/v1/organizations/{org_id}/documents/{document_id}')
  Future<DocumentRead> getDocument({
    @Path('document_id') required String documentId,
    @Path('org_id') required String orgId,
  });

  /// Update Document
  @PATCH('/api/v1/organizations/{org_id}/documents/{document_id}')
  Future<DocumentRead> updateDocument({
    @Path('document_id') required String documentId,
    @Path('org_id') required String orgId,
    @Body() required DocumentUpdate body,
  });

  /// Complete Upload.
  ///
  /// Confirm the upload finished. The stored file's size is checked against the declared one.
  @POST(
    '/api/v1/organizations/{org_id}/documents/{document_id}/complete-upload',
  )
  Future<DocumentRead> completeUpload({
    @Path('document_id') required String documentId,
    @Path('org_id') required String orgId,
  });

  /// Get Download Url.
  ///
  /// A short-lived link to the stored file of a cloud document.
  @GET('/api/v1/organizations/{org_id}/documents/{document_id}/download-url')
  Future<DownloadLink> getDownloadUrl({
    @Path('document_id') required String documentId,
    @Path('org_id') required String orgId,
  });

  /// Get Upload Url.
  ///
  /// Fresh upload instructions, for when the first ones expired before the upload finished.
  @GET('/api/v1/organizations/{org_id}/documents/{document_id}/upload-url')
  Future<UploadInstructions> getUploadUrl({
    @Path('document_id') required String documentId,
    @Path('org_id') required String orgId,
  });
}
