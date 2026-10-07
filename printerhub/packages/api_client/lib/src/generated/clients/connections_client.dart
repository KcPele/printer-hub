// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/connection_create.dart';
import '../models/connection_credentials_output.dart';
import '../models/connection_health_report.dart';
import '../models/connection_priority_update.dart';
import '../models/connection_read.dart';
import '../models/connection_update.dart';

part 'connections_client.g.dart';

@RestApi()
abstract class ConnectionsClient {
  factory ConnectionsClient(Dio dio, {String? baseUrl}) = _ConnectionsClient;

  /// List Connections.
  ///
  /// Connections in fallback order, most preferred first.
  @GET('/api/v1/organizations/{org_id}/printers/{printer_id}/connections')
  Future<List<ConnectionRead>> listConnections({
    @Path('printer_id') required String printerId,
    @Path('org_id') required String orgId,
  });

  /// Add Connection
  @POST('/api/v1/organizations/{org_id}/printers/{printer_id}/connections')
  Future<ConnectionRead> addConnection({
    @Path('printer_id') required String printerId,
    @Path('org_id') required String orgId,
    @Body() required ConnectionCreate body,
  });

  /// Set Connection Priority.
  ///
  /// Set the order in which clients try connections (FR-CON-009, FR-CON-011).
  @PUT(
    '/api/v1/organizations/{org_id}/printers/{printer_id}/connections/priority',
  )
  Future<List<ConnectionRead>> setConnectionPriority({
    @Path('printer_id') required String printerId,
    @Path('org_id') required String orgId,
    @Body() required ConnectionPriorityUpdate body,
  });

  /// Remove Connection
  @DELETE(
    '/api/v1/organizations/{org_id}/printers/{printer_id}/connections/{connection_id}',
  )
  Future<void> removeConnection({
    @Path('printer_id') required String printerId,
    @Path('connection_id') required String connectionId,
    @Path('org_id') required String orgId,
  });

  /// Get Connection
  @GET(
    '/api/v1/organizations/{org_id}/printers/{printer_id}/connections/{connection_id}',
  )
  Future<ConnectionRead> getConnection({
    @Path('printer_id') required String printerId,
    @Path('connection_id') required String connectionId,
    @Path('org_id') required String orgId,
  });

  /// Update Connection
  @PATCH(
    '/api/v1/organizations/{org_id}/printers/{printer_id}/connections/{connection_id}',
  )
  Future<ConnectionRead> updateConnection({
    @Path('printer_id') required String printerId,
    @Path('connection_id') required String connectionId,
    @Path('org_id') required String orgId,
    @Body() required ConnectionUpdate body,
  });

  /// Read Connection Credentials.
  ///
  /// Stored credentials, for a client about to use the connection.
  ///
  /// Every read is written to the audit log. Keep the result in platform.
  /// secure storage (FR-MOB-018).
  @GET(
    '/api/v1/organizations/{org_id}/printers/{printer_id}/connections/{connection_id}/credentials',
  )
  Future<ConnectionCredentialsOutput> readConnectionCredentials({
    @Path('printer_id') required String printerId,
    @Path('connection_id') required String connectionId,
    @Path('org_id') required String orgId,
  });

  /// Report Connection Health.
  ///
  /// Report the outcome of using or testing a connection (FR-CON-012, FR-ONB-005).
  @POST(
    '/api/v1/organizations/{org_id}/printers/{printer_id}/connections/{connection_id}/health',
  )
  Future<ConnectionRead> reportConnectionHealth({
    @Path('printer_id') required String printerId,
    @Path('connection_id') required String connectionId,
    @Path('org_id') required String orgId,
    @Body() required ConnectionHealthReport body,
  });
}
