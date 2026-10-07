// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'consumable_input.dart';
import 'device_alert_input.dart';
import 'printer_status_detail_input_scanner_state.dart';
import 'tray_status_input.dart';

part 'printer_status_detail_input.g.dart';

@JsonSerializable()
class PrinterStatusDetailInput {
  const PrinterStatusDetailInput({
    this.scannerState = PrinterStatusDetailInputScannerState.unknown,
    this.alerts,
    this.consumables,
    this.trays,
  });

  factory PrinterStatusDetailInput.fromJson(Map<String, Object?> json) =>
      _$PrinterStatusDetailInputFromJson(json);

  final List<DeviceAlertInput>? alerts;
  final List<ConsumableInput>? consumables;
  @JsonKey(name: 'scanner_state')
  final PrinterStatusDetailInputScannerState scannerState;
  final List<TrayStatusInput>? trays;

  Map<String, Object?> toJson() => _$PrinterStatusDetailInputToJson(this);
}
