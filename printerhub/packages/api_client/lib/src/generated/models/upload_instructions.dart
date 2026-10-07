// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'upload_instructions.g.dart';

/// Send the file bytes with this request, then call `complete-upload`.
@JsonSerializable()
class UploadInstructions {
  const UploadInstructions({
    required this.expiresAt,
    required this.headers,
    required this.method,
    required this.url,
  });

  factory UploadInstructions.fromJson(Map<String, Object?> json) =>
      _$UploadInstructionsFromJson(json);

  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  final Map<String, String> headers;
  final String method;
  final String url;

  Map<String, Object?> toJson() => _$UploadInstructionsToJson(this);
}
