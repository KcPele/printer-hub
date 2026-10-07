// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'printer_read.dart';

part 'pairing_result.g.dart';

@JsonSerializable()
class PairingResult {
  const PairingResult({required this.printer});

  factory PairingResult.fromJson(Map<String, Object?> json) =>
      _$PairingResultFromJson(json);

  final PrinterRead printer;

  Map<String, Object?> toJson() => _$PairingResultToJson(this);
}
