// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/user_read.dart';
import '../models/user_update.dart';

part 'users_client.g.dart';

@RestApi()
abstract class UsersClient {
  factory UsersClient(Dio dio, {String? baseUrl}) = _UsersClient;

  /// Get Me
  @GET('/api/v1/users/me')
  Future<UserRead> getMe();

  /// Update Me
  @PATCH('/api/v1/users/me')
  Future<UserRead> updateMe({@Body() required UserUpdate body});
}
