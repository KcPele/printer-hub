// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'consumable_output.dart';
import 'device_alert_output.dart';
import 'printer_status_detail_output_scanner_state.dart';
import 'tray_status_output.dart';

part 'printer_status_detail_output.g.dart';

@JsonSerializable()
class PrinterStatusDetailOutput {
  const PrinterStatusDetailOutput({
    required this.alerts,
    required this.consumables,
    required this.trays,
    this.scannerState = PrinterStatusDetailOutputScannerState.unknown,
  });

  factory PrinterStatusDetailOutput.fromJson(Map<String, Object?> json) =>
      _$PrinterStatusDetailOutputFromJson(json);

  final List<DeviceAlertOutput> alerts;
  final List<ConsumableOutput> consumables;
  @JsonKey(name: 'scanner_state')
  final PrinterStatusDetailOutputScannerState scannerState;
  final List<TrayStatusOutput> trays;

  Map<String, Object?> toJson() => _$PrinterStatusDetailOutputToJson(this);
}
