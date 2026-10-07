// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_credentials_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionCredentialsOutput _$ConnectionCredentialsOutputFromJson(
  Map<String, dynamic> json,
) => ConnectionCredentialsOutput(
  extra: Map<String, String>.from(json['extra'] as Map),
  password: json['password'] as String?,
  username: json['username'] as String?,
);

Map<String, dynamic> _$ConnectionCredentialsOutputToJson(
  ConnectionCredentialsOutput instance,
) => <String, dynamic>{
  'extra': instance.extra,
  'password': instance.password,
  'username': instance.username,
};
