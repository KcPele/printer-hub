// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'role.dart';
import 'user_summary.dart';

part 'member_read.g.dart';

@JsonSerializable()
class MemberRead {
  const MemberRead({
    required this.joinedAt,
    required this.role,
    required this.user,
  });

  factory MemberRead.fromJson(Map<String, Object?> json) =>
      _$MemberReadFromJson(json);

  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;
  final Role role;
  final UserSummary user;

  Map<String, Object?> toJson() => _$MemberReadToJson(this);
}
