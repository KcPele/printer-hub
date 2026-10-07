// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'clients/account_client.dart';
import 'clients/auth_client.dart';
import 'clients/capabilities_client.dart';
import 'clients/devices_client.dart';
import 'clients/health_client.dart';
import 'clients/organizations_client.dart';
import 'clients/notifications_client.dart';
import 'clients/audit_client.dart';
import 'clients/documents_client.dart';
import 'clients/feature_flags_client.dart';
import 'clients/jobs_client.dart';
import 'clients/presets_client.dart';
import 'clients/printers_client.dart';
import 'clients/connections_client.dart';
import 'clients/pairing_client.dart';
import 'clients/users_client.dart';

/// PrinterHub API `v0.1.0`.
///
/// Shared backend for PrinterHub mobile and web clients. Clients execute print and scan jobs on the local network and report state here.
class PrinterHubApi {
  PrinterHubApi(Dio dio, {String? baseUrl}) : _dio = dio, _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '0.1.0';

  AccountClient? _account;
  AuthClient? _auth;
  CapabilitiesClient? _capabilities;
  DevicesClient? _devices;
  HealthClient? _health;
  OrganizationsClient? _organizations;
  NotificationsClient? _notifications;
  AuditClient? _audit;
  DocumentsClient? _documents;
  FeatureFlagsClient? _featureFlags;
  JobsClient? _jobs;
  PresetsClient? _presets;
  PrintersClient? _printers;
  ConnectionsClient? _connections;
  PairingClient? _pairing;
  UsersClient? _users;

  AccountClient get account =>
      _account ??= AccountClient(_dio, baseUrl: _baseUrl);

  AuthClient get auth => _auth ??= AuthClient(_dio, baseUrl: _baseUrl);

  CapabilitiesClient get capabilities =>
      _capabilities ??= CapabilitiesClient(_dio, baseUrl: _baseUrl);

  DevicesClient get devices =>
      _devices ??= DevicesClient(_dio, baseUrl: _baseUrl);

  HealthClient get health => _health ??= HealthClient(_dio, baseUrl: _baseUrl);

  OrganizationsClient get organizations =>
      _organizations ??= OrganizationsClient(_dio, baseUrl: _baseUrl);

  NotificationsClient get notifications =>
      _notifications ??= NotificationsClient(_dio, baseUrl: _baseUrl);

  AuditClient get audit => _audit ??= AuditClient(_dio, baseUrl: _baseUrl);

  DocumentsClient get documents =>
      _documents ??= DocumentsClient(_dio, baseUrl: _baseUrl);

  FeatureFlagsClient get featureFlags =>
      _featureFlags ??= FeatureFlagsClient(_dio, baseUrl: _baseUrl);

  JobsClient get jobs => _jobs ??= JobsClient(_dio, baseUrl: _baseUrl);

  PresetsClient get presets =>
      _presets ??= PresetsClient(_dio, baseUrl: _baseUrl);

  PrintersClient get printers =>
      _printers ??= PrintersClient(_dio, baseUrl: _baseUrl);

  ConnectionsClient get connections =>
      _connections ??= ConnectionsClient(_dio, baseUrl: _baseUrl);

  PairingClient get pairing =>
      _pairing ??= PairingClient(_dio, baseUrl: _baseUrl);

  UsersClient get users => _users ??= UsersClient(_dio, baseUrl: _baseUrl);
}
