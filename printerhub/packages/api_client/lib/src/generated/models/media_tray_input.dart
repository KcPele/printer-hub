// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'media_tray_input.g.dart';

@JsonSerializable()
class MediaTrayInput {
  const MediaTrayInput({
    required this.id,
    required this.name,
    this.mediaSize,
    this.mediaType,
  });

  factory MediaTrayInput.fromJson(Map<String, Object?> json) =>
      _$MediaTrayInputFromJson(json);

  final String id;
  @JsonKey(name: 'media_size')
  final String? mediaSize;
  @JsonKey(name: 'media_type')
  final String? mediaType;
  final String name;

  Map<String, Object?> toJson() => _$MediaTrayInputToJson(this);
}
