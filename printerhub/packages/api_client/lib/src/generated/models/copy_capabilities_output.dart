// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'copy_capabilities_output.g.dart';

@JsonSerializable()
class CopyCapabilitiesOutput {
  const CopyCapabilitiesOutput({
    this.nativeRemoteControl = false,
    this.supported = false,
  });

  factory CopyCapabilitiesOutput.fromJson(Map<String, Object?> json) =>
      _$CopyCapabilitiesOutputFromJson(json);

  @JsonKey(name: 'native_remote_control')
  final bool nativeRemoteControl;
  final bool supported;

  Map<String, Object?> toJson() => _$CopyCapabilitiesOutputToJson(this);
}
