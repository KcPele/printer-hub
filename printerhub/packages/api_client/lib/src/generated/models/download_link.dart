// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'download_link.g.dart';

@JsonSerializable()
class DownloadLink {
  const DownloadLink({required this.expiresAt, required this.url});

  factory DownloadLink.fromJson(Map<String, Object?> json) =>
      _$DownloadLinkFromJson(json);

  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  final String url;

  Map<String, Object?> toJson() => _$DownloadLinkToJson(this);
}
