// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/job_type.dart';
import '../models/preset_create.dart';
import '../models/preset_read.dart';
import '../models/preset_update.dart';

part 'presets_client.g.dart';

@RestApi()
abstract class PresetsClient {
  factory PresetsClient(Dio dio, {String? baseUrl}) = _PresetsClient;

  /// List Presets.
  ///
  /// The caller's personal presets and the organization's shared ones.
  @GET('/api/v1/organizations/{org_id}/presets')
  Future<List<PresetRead>> listPresets({
    @Path('org_id') required String orgId,
    @Query('type') JobType? type,
    @Query('printer_id') String? printerId,
  });

  /// Create Preset.
  ///
  /// Save settings as a preset.
  ///
  /// A `personal` preset belongs to the caller. An `organization` preset is.
  /// shared with every member and needs `presets.manage_org`.
  @POST('/api/v1/organizations/{org_id}/presets')
  Future<PresetRead> createPreset({
    @Path('org_id') required String orgId,
    @Body() required PresetCreate body,
  });

  /// Delete Preset
  @DELETE('/api/v1/organizations/{org_id}/presets/{preset_id}')
  Future<void> deletePreset({
    @Path('preset_id') required String presetId,
    @Path('org_id') required String orgId,
  });

  /// Get Preset
  @GET('/api/v1/organizations/{org_id}/presets/{preset_id}')
  Future<PresetRead> getPreset({
    @Path('preset_id') required String presetId,
    @Path('org_id') required String orgId,
  });

  /// Update Preset
  @PATCH('/api/v1/organizations/{org_id}/presets/{preset_id}')
  Future<PresetRead> updatePreset({
    @Path('preset_id') required String presetId,
    @Path('org_id') required String orgId,
    @Body() required PresetUpdate body,
  });
}
