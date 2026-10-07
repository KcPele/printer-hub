// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/page_printer_read.dart';
import '../models/printer_capabilities_input.dart';
import '../models/printer_create.dart';
import '../models/printer_read.dart';
import '../models/printer_status_report.dart';
import '../models/printer_update.dart';

part 'printers_client.g.dart';

@RestApi()
abstract class PrintersClient {
  factory PrintersClient(Dio dio, {String? baseUrl}) = _PrintersClient;

  /// List Printers.
  ///
  /// [cursor] - `next_cursor` from the previous page.
  @GET('/api/v1/organizations/{org_id}/printers')
  Future<PagePrinterRead> listPrinters({
    @Path('org_id') required String orgId,
    @Query('cursor') String? cursor,
    @Query('limit') int? limit = 50,
  });

  /// Add Printer.
  ///
  /// Register a printer together with the connection paths the client verified.
  @POST('/api/v1/organizations/{org_id}/printers')
  Future<PrinterRead> addPrinter({
    @Path('org_id') required String orgId,
    @Body() required PrinterCreate body,
  });

  /// Remove Printer
  @DELETE('/api/v1/organizations/{org_id}/printers/{printer_id}')
  Future<void> removePrinter({
    @Path('printer_id') required String printerId,
    @Path('org_id') required String orgId,
  });

  /// Get Printer
  @GET('/api/v1/organizations/{org_id}/printers/{printer_id}')
  Future<PrinterRead> getPrinter({
    @Path('printer_id') required String printerId,
    @Path('org_id') required String orgId,
  });

  /// Update Printer
  @PATCH('/api/v1/organizations/{org_id}/printers/{printer_id}')
  Future<PrinterRead> updatePrinter({
    @Path('printer_id') required String printerId,
    @Path('org_id') required String orgId,
    @Body() required PrinterUpdate body,
  });

  /// Report Capabilities.
  ///
  /// Replace the capability snapshot with what the client just probed.
  @PUT('/api/v1/organizations/{org_id}/printers/{printer_id}/capabilities')
  Future<PrinterRead> reportCapabilities({
    @Path('printer_id') required String printerId,
    @Path('org_id') required String orgId,
    @Body() required PrinterCapabilitiesInput body,
  });

  /// Report Status.
  ///
  /// Report printer state observed on the local network.
  @POST('/api/v1/organizations/{org_id}/printers/{printer_id}/status')
  Future<PrinterRead> reportStatus({
    @Path('printer_id') required String printerId,
    @Path('org_id') required String orgId,
    @Body() required PrinterStatusReport body,
  });
}
