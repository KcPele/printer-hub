// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'role.dart';

part 'member_update.g.dart';

@JsonSerializable()
class MemberUpdate {
  const MemberUpdate({required this.role});

  factory MemberUpdate.fromJson(Map<String, Object?> json) =>
      _$MemberUpdateFromJson(json);

  final Role role;

  Map<String, Object?> toJson() => _$MemberUpdateToJson(this);
}
