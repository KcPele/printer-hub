// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'pairing_payload.dart';

part 'pairing_token_created.g.dart';

@JsonSerializable()
class PairingTokenCreated {
  const PairingTokenCreated({
    required this.deepLink,
    required this.expiresAt,
    required this.payload,
  });

  factory PairingTokenCreated.fromJson(Map<String, Object?> json) =>
      _$PairingTokenCreatedFromJson(json);

  @JsonKey(name: 'deep_link')
  final String deepLink;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  final PairingPayload payload;

  Map<String, Object?> toJson() => _$PairingTokenCreatedToJson(this);
}
