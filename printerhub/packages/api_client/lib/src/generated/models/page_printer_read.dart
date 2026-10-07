// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'printer_read.dart';

part 'page_printer_read.g.dart';

@JsonSerializable()
class PagePrinterRead {
  const PagePrinterRead({required this.items, required this.nextCursor});

  factory PagePrinterRead.fromJson(Map<String, Object?> json) =>
      _$PagePrinterReadFromJson(json);

  final List<PrinterRead> items;
  @JsonKey(name: 'next_cursor')
  final String? nextCursor;

  Map<String, Object?> toJson() => _$PagePrinterReadToJson(this);
}
