// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'role.dart';

part 'invitation_create.g.dart';

@JsonSerializable()
class InvitationCreate {
  const InvitationCreate({required this.email, this.role = Role.user});

  factory InvitationCreate.fromJson(Map<String, Object?> json) =>
      _$InvitationCreateFromJson(json);

  final String email;
  final Role role;

  Map<String, Object?> toJson() => _$InvitationCreateToJson(this);
}
