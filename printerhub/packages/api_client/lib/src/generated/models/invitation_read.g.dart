// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invitation_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvitationRead _$InvitationReadFromJson(Map<String, dynamic> json) =>
    InvitationRead(
      createdAt: DateTime.parse(json['created_at'] as String),
      email: json['email'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      id: json['id'] as String,
      invitedByUserId: json['invited_by_user_id'] as String?,
      role: Role.fromJson(json['role'] as String),
    );

Map<String, dynamic> _$InvitationReadToJson(InvitationRead instance) =>
    <String, dynamic>{
      'created_at': instance.createdAt.toIso8601String(),
      'email': instance.email,
      'expires_at': instance.expiresAt.toIso8601String(),
      'id': instance.id,
      'invited_by_user_id': ?instance.invitedByUserId,
      'role': instance.role.toJson(),
    };
