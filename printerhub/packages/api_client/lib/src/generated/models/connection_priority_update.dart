// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'connection_priority_update.g.dart';

@JsonSerializable()
class ConnectionPriorityUpdate {
  const ConnectionPriorityUpdate({required this.connectionIds});

  factory ConnectionPriorityUpdate.fromJson(Map<String, Object?> json) =>
      _$ConnectionPriorityUpdateFromJson(json);

  /// Every connection of the printer, most preferred first
  @JsonKey(name: 'connection_ids')
  final List<String> connectionIds;

  Map<String, Object?> toJson() => _$ConnectionPriorityUpdateToJson(this);
}
