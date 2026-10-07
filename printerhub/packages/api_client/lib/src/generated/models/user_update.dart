// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'user_preferences_input.dart';

part 'user_update.g.dart';

@JsonSerializable()
class UserUpdate {
  const UserUpdate({this.name, this.preferences});

  factory UserUpdate.fromJson(Map<String, Object?> json) =>
      _$UserUpdateFromJson(json);

  final String? name;
  final UserPreferencesInput? preferences;

  Map<String, Object?> toJson() => _$UserUpdateToJson(this);
}
