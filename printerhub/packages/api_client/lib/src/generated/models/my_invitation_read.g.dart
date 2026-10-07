// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_invitation_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyInvitationRead _$MyInvitationReadFromJson(Map<String, dynamic> json) =>
    MyInvitationRead(
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      organizationName: json['organization_name'] as String,
      role: Role.fromJson(json['role'] as String),
    );

Map<String, dynamic> _$MyInvitationReadToJson(MyInvitationRead instance) =>
    <String, dynamic>{
      'created_at': instance.createdAt.toIso8601String(),
      'expires_at': instance.expiresAt.toIso8601String(),
      'id': instance.id,
      'organization_id': instance.organizationId,
      'organization_name': instance.organizationName,
      'role': instance.role.toJson(),
    };
