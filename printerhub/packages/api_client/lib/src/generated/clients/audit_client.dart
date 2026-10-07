// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/page_audit_log_read.dart';

part 'audit_client.g.dart';

@RestApi()
abstract class AuditClient {
  factory AuditClient(Dio dio, {String? baseUrl}) = _AuditClient;

  /// List Audit Logs.
  ///
  /// [cursor] - `next_cursor` from the previous page.
  @GET('/api/v1/organizations/{org_id}/audit-logs')
  Future<PageAuditLogRead> listAuditLogs({
    @Path('org_id') required String orgId,
    @Query('limit') int? limit = 50,
    @Query('action') String? action,
    @Query('actor_user_id') String? actorUserId,
    @Query('target_type') String? targetType,
    @Query('target_id') String? targetId,
    @Query('cursor') String? cursor,
  });
}
