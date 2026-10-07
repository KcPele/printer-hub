// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'pairing_redeem.g.dart';

@JsonSerializable()
class PairingRedeem {
  const PairingRedeem({required this.token});

  factory PairingRedeem.fromJson(Map<String, Object?> json) =>
      _$PairingRedeemFromJson(json);

  final String token;

  Map<String, Object?> toJson() => _$PairingRedeemToJson(this);
}
