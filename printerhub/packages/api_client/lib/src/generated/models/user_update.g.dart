// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserUpdate _$UserUpdateFromJson(Map<String, dynamic> json) => UserUpdate(
  name: json['name'] as String?,
  preferences: json['preferences'] == null
      ? null
      : UserPreferencesInput.fromJson(
          json['preferences'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$UserUpdateToJson(UserUpdate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'preferences': instance.preferences,
    };
