// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_printer_read.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PagePrinterRead _$PagePrinterReadFromJson(Map<String, dynamic> json) =>
    PagePrinterRead(
      items: (json['items'] as List<dynamic>)
          .map((e) => PrinterRead.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );

Map<String, dynamic> _$PagePrinterReadToJson(PagePrinterRead instance) =>
    <String, dynamic>{
      'items': instance.items,
      'next_cursor': instance.nextCursor,
    };
