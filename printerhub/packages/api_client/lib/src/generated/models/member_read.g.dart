// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberRead _$MemberReadFromJson(Map<String, dynamic> json) => MemberRead(
  joinedAt: DateTime.parse(json['joined_at'] as String),
  role: Role.fromJson(json['role'] as String),
  user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MemberReadToJson(MemberRead instance) =>
    <String, dynamic>{
      'joined_at': instance.joinedAt.toIso8601String(),
      'role': instance.role.toJson(),
      'user': instance.user.toJson(),
    };
