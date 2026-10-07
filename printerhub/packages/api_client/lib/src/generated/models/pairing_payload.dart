// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'pairing_payload.g.dart';

/// Content to encode in the QR code. Holds no credentials (FR-SEC-013).
@JsonSerializable()
class PairingPayload {
  const PairingPayload({
    required this.organizationId,
    required this.printerId,
    required this.token,
    this.v = 1,
  });

  factory PairingPayload.fromJson(Map<String, Object?> json) =>
      _$PairingPayloadFromJson(json);

  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'printer_id')
  final String printerId;
  final String token;
  final int v;

  Map<String, Object?> toJson() => _$PairingPayloadToJson(this);
}
