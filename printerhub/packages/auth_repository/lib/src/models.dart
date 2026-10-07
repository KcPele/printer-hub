import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';

/// The person signed in on this device.
class User extends Equatable {
  const new({
    required this.id,
    required this.email,
    required this.name,
    required this.emailVerified,
    required this.appTheme,
    this.defaultOrganizationId,
  });

  factory fromApi(UserRead user) {
    return User(
      id: user.id,
      email: user.email,
      name: user.name,
      emailVerified: user.emailVerifiedAt != null,
      appTheme: user.preferences.appTheme.json ?? 'mint',
      defaultOrganizationId: user.preferences.defaultOrganizationId,
    );
  }

  final String id;
  final String email;
  final String name;

  /// False until the emailed code has been entered.
  final bool emailVerified;

  /// The theme saved with the account: `mint`, `indigo`, or `volt`.
  final String appTheme;

  /// The organization the user last worked in, on any device.
  final String? defaultOrganizationId;

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    emailVerified,
    appTheme,
    defaultOrganizationId,
  ];
}

/// A place the account is signed in.
class UserSession extends Equatable {
  const new({
    required this.id,
    required this.isCurrent,
    required this.lastUsedAt,
    this.userAgent,
    this.ip,
  });

  factory fromApi(SessionRead session) {
    return UserSession(
      id: session.id,
      isCurrent: session.isCurrent,
      lastUsedAt: session.lastUsedAt,
      userAgent: session.userAgent,
      ip: session.ip,
    );
  }

  final String id;

  /// True for the session this device is using.
  final bool isCurrent;
  final DateTime lastUsedAt;
  final String? userAgent;
  final String? ip;

  @override
  List<Object?> get props => [id, isCurrent, lastUsedAt, userAgent, ip];
}
