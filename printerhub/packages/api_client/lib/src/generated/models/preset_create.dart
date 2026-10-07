// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'copy_preset_create.dart';
import 'copy_settings_input.dart';
import 'preset_scope.dart';
import 'print_preset_create.dart';
import 'print_settings_input.dart';
import 'scan_preset_create.dart';
import 'scan_settings_input.dart';

part 'preset_create.g.dart';

@JsonSerializable(createFactory: false)
sealed class PresetCreate {
  const PresetCreate();

  factory PresetCreate.fromJson(Map<String, dynamic> json) =>
      PresetCreateSealedDeserializer.tryDeserialize(json);

  Map<String, dynamic> toJson();
}

extension PresetCreateSealedDeserializer on PresetCreate {
  static PresetCreate tryDeserialize(
    Map<String, dynamic> json, {
    String key = 'type',
    Map<Type, Object?>? mapping,
  }) {
    final mappingFallback = const <Type, Object?>{
      PresetCreateCopyPresetCreate: 'copy',
      PresetCreatePrintPresetCreate: 'print',
      PresetCreateScanPresetCreate: 'scan',
    };
    final value = json[key];
    final effective = mapping ?? mappingFallback;
    return switch (value) {
      _ when value == effective[PresetCreateCopyPresetCreate] =>
        PresetCreateCopyPresetCreate.fromJson(json),
      _ when value == effective[PresetCreatePrintPresetCreate] =>
        PresetCreatePrintPresetCreate.fromJson(json),
      _ when value == effective[PresetCreateScanPresetCreate] =>
        PresetCreateScanPresetCreate.fromJson(json),
      _ => throw FormatException(
        'Unknown discriminator value "${json[key]}" for PresetCreate',
      ),
    };
  }
}

@JsonSerializable()
class PresetCreateCopyPresetCreate extends PresetCreate
    implements CopyPresetCreate {
  @override
  final bool isDefault;
  @override
  final String name;
  @override
  final String? printerId;
  @override
  final PresetScope scope;
  @override
  final CopySettingsInput? settings;
  @override
  final String type;

  const PresetCreateCopyPresetCreate({
    required this.isDefault,
    required this.name,
    required this.printerId,
    required this.scope,
    required this.settings,
    required this.type,
  });

  factory PresetCreateCopyPresetCreate.fromJson(Map<String, dynamic> json) =>
      _$PresetCreateCopyPresetCreateFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PresetCreateCopyPresetCreateToJson(this);
}

@JsonSerializable()
class PresetCreatePrintPresetCreate extends PresetCreate
    implements PrintPresetCreate {
  @override
  final bool isDefault;
  @override
  final String name;
  @override
  final String? printerId;
  @override
  final PresetScope scope;
  @override
  final PrintSettingsInput? settings;
  @override
  final String type;

  const PresetCreatePrintPresetCreate({
    required this.isDefault,
    required this.name,
    required this.printerId,
    required this.scope,
    required this.settings,
    required this.type,
  });

  factory PresetCreatePrintPresetCreate.fromJson(Map<String, dynamic> json) =>
      _$PresetCreatePrintPresetCreateFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PresetCreatePrintPresetCreateToJson(this);
}

@JsonSerializable()
class PresetCreateScanPresetCreate extends PresetCreate
    implements ScanPresetCreate {
  @override
  final bool isDefault;
  @override
  final String name;
  @override
  final String? printerId;
  @override
  final PresetScope scope;
  @override
  final ScanSettingsInput? settings;
  @override
  final String type;

  const PresetCreateScanPresetCreate({
    required this.isDefault,
    required this.name,
    required this.printerId,
    required this.scope,
    required this.settings,
    required this.type,
  });

  factory PresetCreateScanPresetCreate.fromJson(Map<String, dynamic> json) =>
      _$PresetCreateScanPresetCreateFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PresetCreateScanPresetCreateToJson(this);
}
