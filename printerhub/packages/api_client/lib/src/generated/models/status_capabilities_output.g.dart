// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_capabilities_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StatusCapabilitiesOutput _$StatusCapabilitiesOutputFromJson(
  Map<String, dynamic> json,
) => StatusCapabilitiesOutput(
  consumables: json['consumables'] as bool? ?? false,
  reporting: json['reporting'] as bool? ?? false,
  trays: json['trays'] as bool? ?? false,
);

Map<String, dynamic> _$StatusCapabilitiesOutputToJson(
  StatusCapabilitiesOutput instance,
) => <String, dynamic>{
  'consumables': instance.consumables,
  'reporting': instance.reporting,
  'trays': instance.trays,
};
