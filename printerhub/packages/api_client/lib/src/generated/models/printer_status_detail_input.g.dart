// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_status_detail_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrinterStatusDetailInput _$PrinterStatusDetailInputFromJson(
  Map<String, dynamic> json,
) => PrinterStatusDetailInput(
  scannerState: json['scanner_state'] == null
      ? PrinterStatusDetailInputScannerState.unknown
      : PrinterStatusDetailInputScannerState.fromJson(
          json['scanner_state'] as String,
        ),
  alerts: (json['alerts'] as List<dynamic>?)
      ?.map((e) => DeviceAlertInput.fromJson(e as Map<String, dynamic>))
      .toList(),
  consumables: (json['consumables'] as List<dynamic>?)
      ?.map((e) => ConsumableInput.fromJson(e as Map<String, dynamic>))
      .toList(),
  trays: (json['trays'] as List<dynamic>?)
      ?.map((e) => TrayStatusInput.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PrinterStatusDetailInputToJson(
  PrinterStatusDetailInput instance,
) => <String, dynamic>{
  'alerts': instance.alerts,
  'consumables': instance.consumables,
  'scanner_state': instance.scannerState,
  'trays': instance.trays,
};
