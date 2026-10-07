// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DownloadLink _$DownloadLinkFromJson(Map<String, dynamic> json) => DownloadLink(
  expiresAt: DateTime.parse(json['expires_at'] as String),
  url: json['url'] as String,
);

Map<String, dynamic> _$DownloadLinkToJson(DownloadLink instance) =>
    <String, dynamic>{
      'expires_at': instance.expiresAt.toIso8601String(),
      'url': instance.url,
    };
