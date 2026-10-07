// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'user_preferences_output_app_theme.dart';
import 'user_preferences_output_theme.dart';

part 'user_preferences_output.g.dart';

@JsonSerializable()
class UserPreferencesOutput {
  const UserPreferencesOutput({
    required this.defaultOrganizationId,
    required this.defaultPrinterId,
    required this.mutedNotificationTypes,
    this.appTheme = UserPreferencesOutputAppTheme.mint,
    this.theme = UserPreferencesOutputTheme.system,
  });

  factory UserPreferencesOutput.fromJson(Map<String, Object?> json) =>
      _$UserPreferencesOutputFromJson(json);

  @JsonKey(name: 'app_theme')
  final UserPreferencesOutputAppTheme appTheme;
  @JsonKey(name: 'default_organization_id')
  final String? defaultOrganizationId;
  @JsonKey(name: 'default_printer_id')
  final String? defaultPrinterId;
  @JsonKey(name: 'muted_notification_types')
  final List<String> mutedNotificationTypes;
  final UserPreferencesOutputTheme theme;

  Map<String, Object?> toJson() => _$UserPreferencesOutputToJson(this);
}
