// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'invitation_accept.g.dart';

@JsonSerializable()
class InvitationAccept {
  const InvitationAccept({required this.token});

  factory InvitationAccept.fromJson(Map<String, Object?> json) =>
      _$InvitationAcceptFromJson(json);

  final String token;

  Map<String, Object?> toJson() => _$InvitationAcceptToJson(this);
}
