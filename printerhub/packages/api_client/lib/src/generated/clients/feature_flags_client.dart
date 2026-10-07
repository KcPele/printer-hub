// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/resolved_flags.dart';

part 'feature_flags_client.g.dart';

@RestApi()
abstract class FeatureFlagsClient {
  factory FeatureFlagsClient(Dio dio, {String? baseUrl}) = _FeatureFlagsClient;

  /// Get Feature Flags.
  ///
  /// Flags as they apply to this organization. Treat a flag that is absent as off.
  @GET('/api/v1/organizations/{org_id}/feature-flags')
  Future<ResolvedFlags> getFeatureFlags({
    @Path('org_id') required String orgId,
  });
}
