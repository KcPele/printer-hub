// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_status_detail_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrinterStatusDetailOutput _$PrinterStatusDetailOutputFromJson(
  Map<String, dynamic> json,
) => PrinterStatusDetailOutput(
  alerts: (json['alerts'] as List<dynamic>)
      .map((e) => DeviceAlertOutput.fromJson(e as Map<String, dynamic>))
      .toList(),
  consumables: (json['consumables'] as List<dynamic>)
      .map((e) => ConsumableOutput.fromJson(e as Map<String, dynamic>))
      .toList(),
  trays: (json['trays'] as List<dynamic>)
      .map((e) => TrayStatusOutput.fromJson(e as Map<String, dynamic>))
      .toList(),
  scannerState: json['scanner_state'] == null
      ? PrinterStatusDetailOutputScannerState.unknown
      : PrinterStatusDetailOutputScannerState.fromJson(
          json['scanner_state'] as String,
        ),
);

Map<String, dynamic> _$PrinterStatusDetailOutputToJson(
  PrinterStatusDetailOutput instance,
) => <String, dynamic>{
  'alerts': instance.alerts.map((e) => e.toJson()).toList(),
  'consumables': instance.consumables.map((e) => e.toJson()).toList(),
  'scanner_state': instance.scannerState.toJson(),
  'trays': instance.trays.map((e) => e.toJson()).toList(),
};
