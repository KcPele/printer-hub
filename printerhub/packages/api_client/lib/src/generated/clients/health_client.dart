// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/liveness.dart';
import '../models/readiness.dart';

part 'health_client.g.dart';

@RestApi()
abstract class HealthClient {
  factory HealthClient(Dio dio, {String? baseUrl}) = _HealthClient;

  /// Live.
  ///
  /// The process is running.
  @GET('/api/v1/health/live')
  Future<Liveness> live();

  /// Ready.
  ///
  /// The process can reach its dependencies and serve traffic.
  @GET('/api/v1/health/ready')
  Future<Readiness> ready();
}
