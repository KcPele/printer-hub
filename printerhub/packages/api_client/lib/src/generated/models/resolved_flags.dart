// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'resolved_flags.g.dart';

@JsonSerializable()
class ResolvedFlags {
  const ResolvedFlags({required this.flags});

  factory ResolvedFlags.fromJson(Map<String, Object?> json) =>
      _$ResolvedFlagsFromJson(json);

  /// Every known flag with its value for this organization
  final Map<String, bool> flags;

  Map<String, Object?> toJson() => _$ResolvedFlagsToJson(this);
}
