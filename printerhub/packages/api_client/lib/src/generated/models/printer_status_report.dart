// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'printer_status.dart';
import 'printer_status_detail_input.dart';

part 'printer_status_report.g.dart';

/// Printer state as observed by a client on the local network.
@JsonSerializable()
class PrinterStatusReport {
  const PrinterStatusReport({required this.status, this.detail});

  factory PrinterStatusReport.fromJson(Map<String, Object?> json) =>
      _$PrinterStatusReportFromJson(json);

  /// Omit to keep the last reported detail
  final PrinterStatusDetailInput? detail;
  final PrinterStatus status;

  Map<String, Object?> toJson() => _$PrinterStatusReportToJson(this);
}
