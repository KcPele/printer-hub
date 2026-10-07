// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_capabilities_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CopyCapabilitiesInput _$CopyCapabilitiesInputFromJson(
  Map<String, dynamic> json,
) => CopyCapabilitiesInput(
  nativeRemoteControl: json['native_remote_control'] as bool? ?? false,
  supported: json['supported'] as bool? ?? false,
);

Map<String, dynamic> _$CopyCapabilitiesInputToJson(
  CopyCapabilitiesInput instance,
) => <String, dynamic>{
  'native_remote_control': instance.nativeRemoteControl,
  'supported': instance.supported,
};
