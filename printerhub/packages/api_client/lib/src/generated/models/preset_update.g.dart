// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preset_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PresetUpdate _$PresetUpdateFromJson(Map<String, dynamic> json) => PresetUpdate(
  isDefault: json['is_default'] as bool?,
  name: json['name'] as String?,
  settings: json['settings'],
);

Map<String, dynamic> _$PresetUpdateToJson(PresetUpdate instance) =>
    <String, dynamic>{
      'is_default': instance.isDefault,
      'name': instance.name,
      'settings': instance.settings,
    };
