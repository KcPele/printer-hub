// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPreferencesInput _$UserPreferencesInputFromJson(
  Map<String, dynamic> json,
) => UserPreferencesInput(
  defaultOrganizationId: json['default_organization_id'] as String?,
  defaultPrinterId: json['default_printer_id'] as String?,
  mutedNotificationTypes: (json['muted_notification_types'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  appTheme: json['app_theme'] == null
      ? UserPreferencesInputAppTheme.volt
      : UserPreferencesInputAppTheme.fromJson(json['app_theme'] as String),
  theme: json['theme'] == null
      ? UserPreferencesInputTheme.system
      : UserPreferencesInputTheme.fromJson(json['theme'] as String),
);

Map<String, dynamic> _$UserPreferencesInputToJson(
  UserPreferencesInput instance,
) => <String, dynamic>{
  'app_theme': instance.appTheme,
  'default_organization_id': instance.defaultOrganizationId,
  'default_printer_id': instance.defaultPrinterId,
  'muted_notification_types': instance.mutedNotificationTypes,
  'theme': instance.theme,
};
