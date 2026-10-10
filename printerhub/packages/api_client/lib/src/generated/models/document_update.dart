// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'document_update.g.dart';

/// Fields left out are unchanged.
@JsonSerializable()
class DocumentUpdate {
  const DocumentUpdate({
    this.fileName,
    this.ocrText,
    this.pageCount,
    this.shared,
    this.tags,
  });

  factory DocumentUpdate.fromJson(Map<String, Object?> json) =>
      _$DocumentUpdateFromJson(json);

  @JsonKey(name: 'file_name')
  final String? fileName;
  @JsonKey(name: 'ocr_text')
  final String? ocrText;
  @JsonKey(name: 'page_count')
  final int? pageCount;
  final bool? shared;
  final List<String>? tags;

  Map<String, Object?> toJson() => _$DocumentUpdateToJson(this);
}
