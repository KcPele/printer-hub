// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionUpdate _$ConnectionUpdateFromJson(Map<String, dynamic> json) =>
    ConnectionUpdate(
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
      purposes: (json['purposes'] as List<dynamic>?)
          ?.map((e) => ConnectionPurpose.fromJson(e as String))
          .toList(),
    );

Map<String, dynamic> _$ConnectionUpdateToJson(ConnectionUpdate instance) =>
    <String, dynamic>{
      'configuration': instance.configuration,
      'credentials': instance.credentials,
      'purposes': instance.purposes,
    };
