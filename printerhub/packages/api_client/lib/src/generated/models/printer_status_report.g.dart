// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_status_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrinterStatusReport _$PrinterStatusReportFromJson(Map<String, dynamic> json) =>
    PrinterStatusReport(
      status: PrinterStatus.fromJson(json['status'] as String),
      detail: json['detail'] == null
          ? null
          : PrinterStatusDetailInput.fromJson(
              json['detail'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$PrinterStatusReportToJson(
  PrinterStatusReport instance,
) => <String, dynamic>{
  'detail': ?instance.detail?.toJson(),
  'status': instance.status.toJson(),
};
