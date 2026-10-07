// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'connection_read.dart';
import 'printer_capabilities_output.dart';
import 'printer_status.dart';
import 'printer_status_detail_output.dart';

part 'printer_read.g.dart';

@JsonSerializable()
class PrinterRead {
  const PrinterRead({
    required this.autoFallbackEnabled,
    required this.capabilities,
    required this.capabilitiesUpdatedAt,
    required this.connections,
    required this.createdAt,
    required this.defaultConnectionId,
    required this.friendlyName,
    required this.id,
    required this.lastSeenAt,
    required this.location,
    required this.manufacturer,
    required this.model,
    required this.organizationId,
    required this.serialNumber,
    required this.status,
    required this.statusDetail,
    required this.updatedAt,
  });

  factory PrinterRead.fromJson(Map<String, Object?> json) =>
      _$PrinterReadFromJson(json);

  @JsonKey(name: 'auto_fallback_enabled')
  final bool autoFallbackEnabled;
  final PrinterCapabilitiesOutput? capabilities;
  @JsonKey(name: 'capabilities_updated_at')
  final DateTime? capabilitiesUpdatedAt;
  final List<ConnectionRead> connections;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  /// The most preferred connection, if any
  @JsonKey(name: 'default_connection_id')
  final String? defaultConnectionId;
  @JsonKey(name: 'friendly_name')
  final String friendlyName;
  final String id;
  @JsonKey(name: 'last_seen_at')
  final DateTime? lastSeenAt;
  final String? location;
  final String? manufacturer;
  final String? model;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'serial_number')
  final String? serialNumber;
  final PrinterStatus status;
  @JsonKey(name: 'status_detail')
  final PrinterStatusDetailOutput statusDetail;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, Object?> toJson() => _$PrinterReadToJson(this);
}
