// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'tray_status_input_state.dart';

part 'tray_status_input.g.dart';

@JsonSerializable()
class TrayStatusInput {
  const TrayStatusInput({
    required this.id,
    required this.name,
    this.state = TrayStatusInputState.unknown,
    this.mediaSize,
    this.mediaType,
  });

  factory TrayStatusInput.fromJson(Map<String, Object?> json) =>
      _$TrayStatusInputFromJson(json);

  final String id;
  @JsonKey(name: 'media_size')
  final String? mediaSize;
  @JsonKey(name: 'media_type')
  final String? mediaType;
  final String name;
  final TrayStatusInputState state;

  Map<String, Object?> toJson() => _$TrayStatusInputToJson(this);
}
