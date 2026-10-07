// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/account_delete_request.dart';

part 'account_client.g.dart';

@RestApi()
abstract class AccountClient {
  factory AccountClient(Dio dio, {String? baseUrl}) = _AccountClient;

  /// Delete Account.
  ///
  /// Permanently delete the caller's account. This cannot be undone.
  ///
  /// Organizations where the caller is the only member are deleted with it.
  /// Answers 409 while the caller is the last owner of an organization that.
  /// has other members.
  @POST('/api/v1/account/delete')
  Future<void> deleteAccount({@Body() required AccountDeleteRequest body});
}
