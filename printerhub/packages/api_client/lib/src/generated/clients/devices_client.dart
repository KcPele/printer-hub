// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/device_read.dart';
import '../models/device_register.dart';
import '../models/device_update.dart';

part 'devices_client.g.dart';

@RestApi()
abstract class DevicesClient {
  factory DevicesClient(Dio dio, {String? baseUrl}) = _DevicesClient;

  /// List Devices
  @GET('/api/v1/devices')
  Future<List<DeviceRead>> listDevices();

  /// Register Device.
  ///
  /// Register this installation, or update it if it is already known.
  ///
  /// Call after every sign-in and whenever the push token changes.
  @POST('/api/v1/devices')
  Future<DeviceRead> registerDevice({@Body() required DeviceRegister body});

  /// Delete Device
  @DELETE('/api/v1/devices/{device_id}')
  Future<void> deleteDevice({@Path('device_id') required String deviceId});

  /// Update Device
  @PATCH('/api/v1/devices/{device_id}')
  Future<DeviceRead> updateDevice({
    @Path('device_id') required String deviceId,
    @Body() required DeviceUpdate body,
  });
}
