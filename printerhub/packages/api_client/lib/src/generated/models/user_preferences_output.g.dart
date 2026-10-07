// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPreferencesOutput _$UserPreferencesOutputFromJson(
  Map<String, dynamic> json,
) => UserPreferencesOutput(
  defaultOrganizationId: json['default_organization_id'] as String?,
  defaultPrinterId: json['default_printer_id'] as String?,
  mutedNotificationTypes: (json['muted_notification_types'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  appTheme: json['app_theme'] == null
      ? UserPreferencesOutputAppTheme.mint
      : UserPreferencesOutputAppTheme.fromJson(json['app_theme'] as String),
  theme: json['theme'] == null
      ? UserPreferencesOutputTheme.system
      : UserPreferencesOutputTheme.fromJson(json['theme'] as String),
);

Map<String, dynamic> _$UserPreferencesOutputToJson(
  UserPreferencesOutput instance,
) => <String, dynamic>{
  'app_theme': instance.appTheme.toJson(),
  'default_organization_id': ?instance.defaultOrganizationId,
  'default_printer_id': ?instance.defaultPrinterId,
  'muted_notification_types': instance.mutedNotificationTypes,
  'theme': instance.theme.toJson(),
};
