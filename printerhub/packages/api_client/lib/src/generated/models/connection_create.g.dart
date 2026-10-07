// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionCreate _$ConnectionCreateFromJson(Map<String, dynamic> json) =>
    ConnectionCreate(
      purposes: (json['purposes'] as List<dynamic>)
          .map((e) => ConnectionPurpose.fromJson(e as String))
          .toList(),
      type: ConnectionType.fromJson(json['type'] as String),
      configuration: json['configuration'] == null
          ? null
          : ConnectionConfigurationInput.fromJson(
              json['configuration'] as Map<String, dynamic>,
            ),
      credentials: json['credentials'] == null
          ? null
          : ConnectionCredentialsInput.fromJson(
              json['credentials'] as Map<String, dynamic>,
            ),
      priority: (json['priority'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ConnectionCreateToJson(ConnectionCreate instance) =>
    <String, dynamic>{
      'configuration': instance.configuration,
      'credentials': instance.credentials,
      'priority': instance.priority,
      'purposes': instance.purposes,
      'type': instance.type,
    };
