// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'copy_capabilities_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CopyCapabilitiesOutput _$CopyCapabilitiesOutputFromJson(
  Map<String, dynamic> json,
) => CopyCapabilitiesOutput(
  nativeRemoteControl: json['native_remote_control'] as bool? ?? false,
  supported: json['supported'] as bool? ?? false,
);

Map<String, dynamic> _$CopyCapabilitiesOutputToJson(
  CopyCapabilitiesOutput instance,
) => <String, dynamic>{
  'native_remote_control': instance.nativeRemoteControl,
  'supported': instance.supported,
};
