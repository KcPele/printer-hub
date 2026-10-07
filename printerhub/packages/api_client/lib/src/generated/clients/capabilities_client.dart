// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/capability_profile_read.dart';

part 'capabilities_client.g.dart';

@RestApi()
abstract class CapabilitiesClient {
  factory CapabilitiesClient(Dio dio, {String? baseUrl}) = _CapabilitiesClient;

  /// List Profiles
  @GET('/api/v1/capability-profiles')
  Future<List<CapabilityProfileRead>> listProfiles({
    @Query('manufacturer') String? manufacturer,
  });

  /// Match Profile.
  ///
  /// The vendor baseline for a discovered printer: what to expect and what to probe.
  @GET('/api/v1/capability-profiles/match')
  Future<CapabilityProfileRead> matchProfile({
    @Query('manufacturer') required String manufacturer,
    @Query('model') required String model,
  });
}
