// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'role.dart';

part 'invitation_created.g.dart';

@JsonSerializable()
class InvitationCreated {
  const InvitationCreated({
    required this.createdAt,
    required this.email,
    required this.expiresAt,
    required this.id,
    required this.invitedByUserId,
    required this.role,
    required this.token,
  });

  factory InvitationCreated.fromJson(Map<String, Object?> json) =>
      _$InvitationCreatedFromJson(json);

  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final String email;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  final String id;
  @JsonKey(name: 'invited_by_user_id')
  final String? invitedByUserId;
  final Role role;

  /// Shown once. Share it with the invited person.
  final String token;

  Map<String, Object?> toJson() => _$InvitationCreatedToJson(this);
}
