// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_capabilities_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StatusCapabilitiesInput _$StatusCapabilitiesInputFromJson(
  Map<String, dynamic> json,
) => StatusCapabilitiesInput(
  consumables: json['consumables'] as bool? ?? false,
  reporting: json['reporting'] as bool? ?? false,
  trays: json['trays'] as bool? ?? false,
);

Map<String, dynamic> _$StatusCapabilitiesInputToJson(
  StatusCapabilitiesInput instance,
) => <String, dynamic>{
  'consumables': instance.consumables,
  'reporting': instance.reporting,
  'trays': instance.trays,
};
