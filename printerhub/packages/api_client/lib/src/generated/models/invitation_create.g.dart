// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invitation_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvitationCreate _$InvitationCreateFromJson(Map<String, dynamic> json) =>
    InvitationCreate(
      email: json['email'] as String,
      role: json['role'] == null
          ? Role.user
          : Role.fromJson(json['role'] as String),
    );

Map<String, dynamic> _$InvitationCreateToJson(InvitationCreate instance) =>
    <String, dynamic>{'email': instance.email, 'role': instance.role};
