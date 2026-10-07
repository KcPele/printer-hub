// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'role.dart';

part 'my_invitation_read.g.dart';

/// An invitation as seen by the person invited.
@JsonSerializable()
class MyInvitationRead {
  const MyInvitationRead({
    required this.createdAt,
    required this.expiresAt,
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.role,
  });

  factory MyInvitationRead.fromJson(Map<String, Object?> json) =>
      _$MyInvitationReadFromJson(json);

  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'organization_name')
  final String organizationName;
  final Role role;

  Map<String, Object?> toJson() => _$MyInvitationReadToJson(this);
}
