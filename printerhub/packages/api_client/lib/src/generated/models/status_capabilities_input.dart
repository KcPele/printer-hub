// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'status_capabilities_input.g.dart';

@JsonSerializable()
class StatusCapabilitiesInput {
  const StatusCapabilitiesInput({
    this.consumables = false,
    this.reporting = false,
    this.trays = false,
  });

  factory StatusCapabilitiesInput.fromJson(Map<String, Object?> json) =>
      _$StatusCapabilitiesInputFromJson(json);

  final bool consumables;
  final bool reporting;
  final bool trays;

  Map<String, Object?> toJson() => _$StatusCapabilitiesInputToJson(this);
}
