// Reads the phone through plugins, which only exist on a device.
// coverage:ignore-file

import 'dart:io';

import 'package:auth_repository/auth_repository.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What this phone is, for the list of devices on the account.
Future<PhoneDetails> readPhoneDetails() async {
  final app = await PackageInfo.fromPlatform();
  final appVersion = '${app.version} (${app.buildNumber})';
  final plugin = DeviceInfoPlugin();

  if (Platform.isIOS) {
    final phone = await plugin.iosInfo;
    return PhoneDetails(
      platform: 'ios',
      model: phone.modelName,
      osVersion: '${phone.systemName} ${phone.systemVersion}',
      appVersion: appVersion,
    );
  }
  final phone = await plugin.androidInfo;
  return PhoneDetails(
    platform: 'android',
    model: '${phone.manufacturer} ${phone.model}',
    osVersion: 'Android ${phone.version.release}',
    appVersion: appVersion,
  );
}
