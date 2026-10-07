// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/pairing_redeem.dart';
import '../models/pairing_result.dart';
import '../models/pairing_token_created.dart';

part 'pairing_client.g.dart';

@RestApi()
abstract class PairingClient {
  factory PairingClient(Dio dio, {String? baseUrl}) = _PairingClient;

  /// Create Pairing Token.
  ///
  /// Create a short-lived, single-use pairing code to show as a QR code.
  @POST('/api/v1/organizations/{org_id}/printers/{printer_id}/pairing-tokens')
  Future<PairingTokenCreated> createPairingToken({
    @Path('printer_id') required String printerId,
    @Path('org_id') required String orgId,
  });

  /// Redeem Pairing Token.
  ///
  /// Resolve a scanned pairing code to its printer profile and connections.
  @POST('/api/v1/pairing/redeem')
  Future<PairingResult> redeemPairingToken({
    @Body() required PairingRedeem body,
  });
}
