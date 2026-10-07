// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'role.dart';

part 'invitation_read.g.dart';

@JsonSerializable()
class InvitationRead {
  const InvitationRead({
    required this.createdAt,
    required this.email,
    required this.expiresAt,
    required this.id,
    required this.invitedByUserId,
    required this.role,
  });

  factory InvitationRead.fromJson(Map<String, Object?> json) =>
      _$InvitationReadFromJson(json);

  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final String email;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  final String id;
  @JsonKey(name: 'invited_by_user_id')
  final String? invitedByUserId;
  final Role role;

  Map<String, Object?> toJson() => _$InvitationReadToJson(this);
}
