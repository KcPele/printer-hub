// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'consumable_output_state.dart';

part 'consumable_output.g.dart';

/// Toner, ink, drum, and similar supplies (FR-MON-002).
@JsonSerializable()
class ConsumableOutput {
  const ConsumableOutput({
    required this.color,
    required this.kind,
    required this.levelPercent,
    required this.name,
    this.state = ConsumableOutputState.unknown,
  });

  factory ConsumableOutput.fromJson(Map<String, Object?> json) =>
      _$ConsumableOutputFromJson(json);

  final String? color;

  /// toner, ink, drum, waste_toner, fuser, ...
  final String kind;
  @JsonKey(name: 'level_percent')
  final int? levelPercent;
  final String name;
  final ConsumableOutputState state;

  Map<String, Object?> toJson() => _$ConsumableOutputToJson(this);
}
