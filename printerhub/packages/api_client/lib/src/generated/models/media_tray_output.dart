// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'media_tray_output.g.dart';

@JsonSerializable()
class MediaTrayOutput {
  const MediaTrayOutput({
    required this.id,
    required this.mediaSize,
    required this.mediaType,
    required this.name,
  });

  factory MediaTrayOutput.fromJson(Map<String, Object?> json) =>
      _$MediaTrayOutputFromJson(json);

  final String id;
  @JsonKey(name: 'media_size')
  final String? mediaSize;
  @JsonKey(name: 'media_type')
  final String? mediaType;
  final String name;

  Map<String, Object?> toJson() => _$MediaTrayOutputToJson(this);
}
