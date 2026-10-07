// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'consumable_input_state.dart';

part 'consumable_input.g.dart';

/// Toner, ink, drum, and similar supplies (FR-MON-002).
@JsonSerializable()
class ConsumableInput {
  const ConsumableInput({
    required this.kind,
    required this.name,
    this.state = ConsumableInputState.unknown,
    this.color,
    this.levelPercent,
  });

  factory ConsumableInput.fromJson(Map<String, Object?> json) =>
      _$ConsumableInputFromJson(json);

  final String? color;

  /// toner, ink, drum, waste_toner, fuser, ...
  final String kind;
  @JsonKey(name: 'level_percent')
  final int? levelPercent;
  final String name;
  final ConsumableInputState state;

  Map<String, Object?> toJson() => _$ConsumableInputToJson(this);
}
