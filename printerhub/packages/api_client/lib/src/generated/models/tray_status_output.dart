// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'tray_status_output_state.dart';

part 'tray_status_output.g.dart';

@JsonSerializable()
class TrayStatusOutput {
  const TrayStatusOutput({
    required this.id,
    required this.mediaSize,
    required this.mediaType,
    required this.name,
    this.state = TrayStatusOutputState.unknown,
  });

  factory TrayStatusOutput.fromJson(Map<String, Object?> json) =>
      _$TrayStatusOutputFromJson(json);

  final String id;
  @JsonKey(name: 'media_size')
  final String? mediaSize;
  @JsonKey(name: 'media_type')
  final String? mediaType;
  final String name;
  final TrayStatusOutputState state;

  Map<String, Object?> toJson() => _$TrayStatusOutputToJson(this);
}
