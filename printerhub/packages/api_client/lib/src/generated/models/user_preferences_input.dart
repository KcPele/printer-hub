// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'user_preferences_input_app_theme.dart';
import 'user_preferences_input_theme.dart';

part 'user_preferences_input.g.dart';

@JsonSerializable()
class UserPreferencesInput {
  const UserPreferencesInput({
    this.defaultOrganizationId,
    this.defaultPrinterId,
    this.mutedNotificationTypes,
    this.appTheme = UserPreferencesInputAppTheme.volt,
    this.theme = UserPreferencesInputTheme.system,
  });

  factory UserPreferencesInput.fromJson(Map<String, Object?> json) =>
      _$UserPreferencesInputFromJson(json);

  @JsonKey(name: 'app_theme')
  final UserPreferencesInputAppTheme appTheme;
  @JsonKey(name: 'default_organization_id')
  final String? defaultOrganizationId;
  @JsonKey(name: 'default_printer_id')
  final String? defaultPrinterId;
  @JsonKey(name: 'muted_notification_types')
  final List<String>? mutedNotificationTypes;
  final UserPreferencesInputTheme theme;

  Map<String, Object?> toJson() => _$UserPreferencesInputToJson(this);
}
