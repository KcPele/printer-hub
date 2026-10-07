// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'token_response.g.dart';

@JsonSerializable()
class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.expiresIn,
    required this.refreshToken,
    required this.sessionId,
    this.tokenType = 'bearer',
  });

  factory TokenResponse.fromJson(Map<String, Object?> json) =>
      _$TokenResponseFromJson(json);

  @JsonKey(name: 'access_token')
  final String accessToken;

  /// Access token lifetime in seconds
  @JsonKey(name: 'expires_in')
  final int expiresIn;
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @JsonKey(name: 'session_id')
  final String sessionId;
  @JsonKey(name: 'token_type')
  final String tokenType;

  Map<String, Object?> toJson() => _$TokenResponseToJson(this);
}
