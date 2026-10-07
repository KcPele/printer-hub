// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserRead _$UserReadFromJson(Map<String, dynamic> json) => UserRead(
  createdAt: DateTime.parse(json['created_at'] as String),
  email: json['email'] as String,
  emailVerifiedAt: json['email_verified_at'] == null
      ? null
      : DateTime.parse(json['email_verified_at'] as String),
  id: json['id'] as String,
  isSuperuser: json['is_superuser'] as bool,
  name: json['name'] as String,
  preferences: UserPreferencesOutput.fromJson(
    json['preferences'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$UserReadToJson(UserRead instance) => <String, dynamic>{
  'created_at': instance.createdAt.toIso8601String(),
  'email': instance.email,
  'email_verified_at': instance.emailVerifiedAt?.toIso8601String(),
  'id': instance.id,
  'is_superuser': instance.isSuperuser,
  'name': instance.name,
  'preferences': instance.preferences,
};
