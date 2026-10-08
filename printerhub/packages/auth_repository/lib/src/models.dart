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
    this.deviceId,
  });

  factory fromApi(SessionRead session) {
    return UserSession(
      id: session.id,
      isCurrent: session.isCurrent,
      lastUsedAt: session.lastUsedAt,
      userAgent: session.userAgent,
      ip: session.ip,
      deviceId: session.deviceId,
    );
  }

  final String id;

  /// True for the session this device is using.
  final bool isCurrent;
  final DateTime lastUsedAt;
  final String? userAgent;
  final String? ip;

  /// The [UserDevice] this session is on, when it registered one.
  final String? deviceId;

  @override
  List<Object?> get props => [
    id,
    isCurrent,
    lastUsedAt,
    userAgent,
    ip,
    deviceId,
  ];
}

/// What this phone tells the backend about itself, so it can be told apart
/// in the list of devices and sent notifications.
class PhoneDetails extends Equatable {
  const new({
    required this.platform,
    this.name,
    this.model,
    this.osVersion,
    this.appVersion,
  });

  /// `ios` or `android`.
  final String platform;

  /// The name its owner gave it, when the system lets an app read that.
  final String? name;

  /// Such as `iPhone 15 Pro` or `Pixel 8`.
  final String? model;
  final String? osVersion;
  final String? appVersion;

  @override
  List<Object?> get props => [platform, name, model, osVersion, appVersion];
}

/// A phone or tablet the account has been used on.
class UserDevice extends Equatable {
  const new({
    required this.id,
    required this.platform,
    required this.lastSeenAt,
    this.name,
    this.model,
    this.osVersion,
    this.appVersion,
    this.pushEnabled = false,
    this.isThisDevice = false,
  });

  factory fromApi(DeviceRead device, {String? installationId}) {
    return UserDevice(
      id: device.id,
      platform: device.platform.json ?? 'unknown',
      lastSeenAt: device.lastSeenAt,
      name: device.name,
      model: device.model,
      osVersion: device.osVersion,
      appVersion: device.appVersion,
      pushEnabled: device.pushEnabled,
      isThisDevice: device.installationId == installationId,
    );
  }

  final String id;

  /// `ios`, `android`, or `web`.
  final String platform;
  final DateTime lastSeenAt;
  final String? name;
  final String? model;
  final String? osVersion;
  final String? appVersion;

  /// True when notifications reach this device.
  final bool pushEnabled;

  /// True for the device the app is running on.
  final bool isThisDevice;

  /// The best thing to call it: its model, else its name, else its
  /// platform.
  String get label => model ?? name ?? platform;

  @override
  List<Object?> get props => [
    id,
    platform,
    lastSeenAt,
    name,
    model,
    osVersion,
    appVersion,
    pushEnabled,
    isThisDevice,
  ];
}
