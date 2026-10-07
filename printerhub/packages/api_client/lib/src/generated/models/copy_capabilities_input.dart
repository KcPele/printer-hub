// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'copy_capabilities_input.g.dart';

@JsonSerializable()
class CopyCapabilitiesInput {
  const CopyCapabilitiesInput({
    this.nativeRemoteControl = false,
    this.supported = false,
  });

  factory CopyCapabilitiesInput.fromJson(Map<String, Object?> json) =>
      _$CopyCapabilitiesInputFromJson(json);

  @JsonKey(name: 'native_remote_control')
  final bool nativeRemoteControl;
  final bool supported;

  Map<String, Object?> toJson() => _$CopyCapabilitiesInputToJson(this);
}
