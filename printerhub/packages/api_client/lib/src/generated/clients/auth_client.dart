// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/auth_response.dart';
import '../models/change_password_request.dart';
import '../models/email_verify_request.dart';
import '../models/login_request.dart';
import '../models/password_forgot_request.dart';
import '../models/password_reset_request.dart';
import '../models/refresh_request.dart';
import '../models/register_request.dart';
import '../models/session_read.dart';
import '../models/token_response.dart';
import '../models/user_read.dart';

part 'auth_client.g.dart';

@RestApi()
abstract class AuthClient {
  factory AuthClient(Dio dio, {String? baseUrl}) = _AuthClient;

  /// Resend Verification.
  ///
  /// Email a new verification code. Any earlier code stops working.
  @POST('/api/v1/auth/email/resend')
  Future<void> resendVerification();

  /// Verify Email.
  ///
  /// Confirm the caller's email address with the code sent at sign-up.
  @POST('/api/v1/auth/email/verify')
  Future<UserRead> verifyEmail({@Body() required EmailVerifyRequest body});

  /// Login
  @POST('/api/v1/auth/login')
  Future<AuthResponse> login({@Body() required LoginRequest body});

  /// Logout
  @POST('/api/v1/auth/logout')
  Future<void> logout();

  /// Change Password.
  ///
  /// Change the password and sign out every other session.
  @POST('/api/v1/auth/password/change')
  Future<void> changePassword({@Body() required ChangePasswordRequest body});

  /// Forgot Password.
  ///
  /// Email a 6-digit reset code.
  ///
  /// Always answers 204, whether or not the address has an account.
  @POST('/api/v1/auth/password/forgot')
  Future<void> forgotPassword({@Body() required PasswordForgotRequest body});

  /// Reset Password.
  ///
  /// Choose a new password using the emailed code. Signs out every session.
  ///
  /// A code works once, expires after a few minutes, and stops working after.
  /// a few wrong attempts.
  @POST('/api/v1/auth/password/reset')
  Future<void> resetPassword({@Body() required PasswordResetRequest body});

  /// Refresh.
  ///
  /// Rotate the refresh token. The submitted token stops working.
  ///
  /// Submitting an already rotated token revokes the session.
  @POST('/api/v1/auth/refresh')
  Future<TokenResponse> refresh({@Body() required RefreshRequest body});

  /// Register
  @POST('/api/v1/auth/register')
  Future<AuthResponse> register({@Body() required RegisterRequest body});

  /// List Sessions
  @GET('/api/v1/auth/sessions')
  Future<List<SessionRead>> listSessions();

  /// Revoke Session
  @DELETE('/api/v1/auth/sessions/{session_id}')
  Future<void> revokeSession({@Path('session_id') required String sessionId});
}
