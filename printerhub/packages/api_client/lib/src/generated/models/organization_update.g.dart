// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganizationUpdate _$OrganizationUpdateFromJson(Map<String, dynamic> json) =>
    OrganizationUpdate(
      name: json['name'] as String?,
      settings: json['settings'] == null
          ? null
          : OrganizationSettingsInput.fromJson(
              json['settings'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$OrganizationUpdateToJson(OrganizationUpdate instance) =>
    <String, dynamic>{'name': instance.name, 'settings': instance.settings};
