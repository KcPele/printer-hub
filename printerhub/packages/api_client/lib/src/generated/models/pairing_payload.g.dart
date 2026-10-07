// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PairingPayload _$PairingPayloadFromJson(Map<String, dynamic> json) =>
    PairingPayload(
      organizationId: json['organization_id'] as String,
      printerId: json['printer_id'] as String,
      token: json['token'] as String,
      v: (json['v'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$PairingPayloadToJson(PairingPayload instance) =>
    <String, dynamic>{
      'organization_id': instance.organizationId,
      'printer_id': instance.printerId,
      'token': instance.token,
      'v': instance.v,
    };
