// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'status_capabilities_output.g.dart';

@JsonSerializable()
class StatusCapabilitiesOutput {
  const StatusCapabilitiesOutput({
    this.consumables = false,
    this.reporting = false,
    this.trays = false,
  });

  factory StatusCapabilitiesOutput.fromJson(Map<String, Object?> json) =>
      _$StatusCapabilitiesOutputFromJson(json);

  final bool consumables;
  final bool reporting;
  final bool trays;

  Map<String, Object?> toJson() => _$StatusCapabilitiesOutputToJson(this);
}
