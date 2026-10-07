// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_credentials_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionCredentialsInput _$ConnectionCredentialsInputFromJson(
  Map<String, dynamic> json,
) => ConnectionCredentialsInput(
  extra: (json['extra'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  password: json['password'] as String?,
  username: json['username'] as String?,
);

Map<String, dynamic> _$ConnectionCredentialsInputToJson(
  ConnectionCredentialsInput instance,
) => <String, dynamic>{
  'extra': instance.extra,
  'password': instance.password,
  'username': instance.username,
};
