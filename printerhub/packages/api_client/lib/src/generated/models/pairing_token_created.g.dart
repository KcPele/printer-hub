// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_token_created.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PairingTokenCreated _$PairingTokenCreatedFromJson(Map<String, dynamic> json) =>
    PairingTokenCreated(
      deepLink: json['deep_link'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      payload: PairingPayload.fromJson(json['payload'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PairingTokenCreatedToJson(
  PairingTokenCreated instance,
) => <String, dynamic>{
  'deep_link': instance.deepLink,
  'expires_at': instance.expiresAt.toIso8601String(),
  'payload': instance.payload.toJson(),
};
