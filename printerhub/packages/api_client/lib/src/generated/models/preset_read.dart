// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'copy_preset_read.dart';
import 'copy_settings_output.dart';
import 'preset_scope.dart';
import 'print_preset_read.dart';
import 'print_settings_output.dart';
import 'scan_preset_read.dart';
import 'scan_settings_output.dart';

part 'preset_read.g.dart';

@JsonSerializable(createFactory: false)
sealed class PresetRead {
  const PresetRead();

  factory PresetRead.fromJson(Map<String, dynamic> json) =>
      PresetReadSealedDeserializer.tryDeserialize(json);

  Map<String, dynamic> toJson();
}

extension PresetReadSealedDeserializer on PresetRead {
  static PresetRead tryDeserialize(
    Map<String, dynamic> json, {
    String key = 'type',
    Map<Type, Object?>? mapping,
  }) {
    final mappingFallback = const <Type, Object?>{
      PresetReadCopyPresetRead: 'copy',
      PresetReadPrintPresetRead: 'print',
      PresetReadScanPresetRead: 'scan',
    };
    final value = json[key];
    final effective = mapping ?? mappingFallback;
    return switch (value) {
      _ when value == effective[PresetReadCopyPresetRead] =>
        PresetReadCopyPresetRead.fromJson(json),
      _ when value == effective[PresetReadPrintPresetRead] =>
        PresetReadPrintPresetRead.fromJson(json),
      _ when value == effective[PresetReadScanPresetRead] =>
        PresetReadScanPresetRead.fromJson(json),
      _ => throw FormatException(
        'Unknown discriminator value "${json[key]}" for PresetRead',
      ),
    };
  }
}

@JsonSerializable()
class PresetReadCopyPresetRead extends PresetRead implements CopyPresetRead {
  @override
  final DateTime createdAt;
  @override
  final String id;
  @override
  final bool isDefault;
  @override
  final String name;
  @override
  final String organizationId;
  @override
  final String? ownerUserId;
  @override
  final String? printerId;
  @override
  final PresetScope scope;
  @override
  final CopySettingsOutput settings;
  @override
  final String type;
  @override
  final DateTime updatedAt;

  const PresetReadCopyPresetRead({
    required this.createdAt,
    required this.id,
    required this.isDefault,
    required this.name,
    required this.organizationId,
    required this.ownerUserId,
    required this.printerId,
    required this.scope,
    required this.settings,
    required this.type,
    required this.updatedAt,
  });

  factory PresetReadCopyPresetRead.fromJson(Map<String, dynamic> json) =>
      _$PresetReadCopyPresetReadFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PresetReadCopyPresetReadToJson(this);
}

@JsonSerializable()
class PresetReadPrintPresetRead extends PresetRead implements PrintPresetRead {
  @override
  final DateTime createdAt;
  @override
  final String id;
  @override
  final bool isDefault;
  @override
  final String name;
  @override
  final String organizationId;
  @override
  final String? ownerUserId;
  @override
  final String? printerId;
  @override
  final PresetScope scope;
  @override
  final PrintSettingsOutput settings;
  @override
  final String type;
  @override
  final DateTime updatedAt;

  const PresetReadPrintPresetRead({
    required this.createdAt,
    required this.id,
    required this.isDefault,
    required this.name,
    required this.organizationId,
    required this.ownerUserId,
    required this.printerId,
    required this.scope,
    required this.settings,
    required this.type,
    required this.updatedAt,
  });

  factory PresetReadPrintPresetRead.fromJson(Map<String, dynamic> json) =>
      _$PresetReadPrintPresetReadFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PresetReadPrintPresetReadToJson(this);
}

@JsonSerializable()
class PresetReadScanPresetRead extends PresetRead implements ScanPresetRead {
  @override
  final DateTime createdAt;
  @override
  final String id;
  @override
  final bool isDefault;
  @override
  final String name;
  @override
  final String organizationId;
  @override
  final String? ownerUserId;
  @override
  final String? printerId;
  @override
  final PresetScope scope;
  @override
  final ScanSettingsOutput settings;
  @override
  final String type;
  @override
  final DateTime updatedAt;

  const PresetReadScanPresetRead({
    required this.createdAt,
    required this.id,
    required this.isDefault,
    required this.name,
    required this.organizationId,
    required this.ownerUserId,
    required this.printerId,
    required this.scope,
    required this.settings,
    required this.type,
    required this.updatedAt,
  });

  factory PresetReadScanPresetRead.fromJson(Map<String, dynamic> json) =>
      _$PresetReadScanPresetReadFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PresetReadScanPresetReadToJson(this);
}
