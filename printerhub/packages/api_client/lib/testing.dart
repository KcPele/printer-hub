// Test support is not part of what the package ships to users.
// coverage:ignore-file

/// A stand-in for the network, for tests of anything built on the client.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// What the fake API answers with.
class FakeResponse {
  const new(this.status, [this.body]);

  /// An `application/problem+json` error, as the API sends them.
  new problem(this.status, String code, {String? detail})
    : body = {
        'type': 'about:blank',
        'title': 'Error',
        'status': status,
        'code': code,
        'detail': detail,
        'request_id': 'req-1',
        'errors': null,
      };

  final int status;
  final Object? body;

  bool get isProblem =>
      status >= 400 && body is Map && (body! as Map)['code'] != null;
}

typedef FakeHandler = Future<FakeResponse> Function(RequestOptions request);

/// Stands in for the network. Records every request and answers from
/// [handler].
class FakeApi implements HttpClientAdapter {
  new(this.handler);

  FakeHandler handler;
  final List<RequestOptions> requests = [];

  /// The requests sent to [path], in order.
  List<RequestOptions> to(String path) =>
      requests.where((request) => request.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = await handler(options);
    return ResponseBody.fromString(
      response.body == null ? '' : jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [
          if (response.isProblem)
            'application/problem+json'
          else
            'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A `TokenResponse` body.
Map<String, Object?> tokenResponse(String access, String refresh) => {
  'access_token': access,
  'refresh_token': refresh,
  'token_type': 'bearer',
  'expires_in': 900,
  'session_id': '0198c0de-0000-7000-8000-000000000001',
};

/// A `UserRead` body.
Map<String, Object?> userBody({String email = 'ada@example.com'}) => {
  'id': '0198c0de-0000-7000-8000-000000000002',
  'email': email,
  'email_verified_at': null,
  'name': 'Ada',
  'preferences': {
    'theme': 'system',
    'app_theme': 'mint',
    'default_organization_id': null,
    'default_printer_id': null,
    'muted_notification_types': <String>[],
  },
  'is_superuser': false,
  'created_at': '2026-10-07T10:00:00Z',
};

/// An `OrganizationRead` body.
Map<String, Object?> organizationBody({
  String id = '0198c0de-0000-7000-8000-00000000000b',
  String name = 'Acme',
  String role = 'owner',
}) => {
  'id': id,
  'name': name,
  'slug': name.toLowerCase(),
  'role': role,
  'settings': {
    'color_printing_roles': ['owner', 'admin', 'operator', 'user'],
    'document_retention_days': null,
    'document_storage_mode': 'cloud_allowed',
    'max_copies_per_job': null,
  },
  'created_at': '2026-10-07T10:00:00Z',
};

/// A `ConnectionRead` body.
Map<String, Object?> connectionBody({
  String type = 'ipp',
  String host = '192.168.1.40',
  int port = 631,
  String path = '/ipp/print',
  int priority = 1,
  String printerId = 'printer-1',
  bool hasCredentials = false,
}) => {
  'id': 'connection-$type-$priority',
  'printer_id': printerId,
  'type': type,
  'purposes': type == 'escl' ? ['scan'] : ['print', 'status'],
  'priority': priority,
  'configuration': {
    'host': host,
    'port': port,
    'path': path,
    'tls': type == 'ipps',
    'service_name': null,
    'ssid': null,
    'options': <String, Object?>{},
  },
  'has_credentials': hasCredentials,
  'health': 'unknown',
  'last_success_at': null,
  'last_failure_at': null,
  'last_latency_ms': null,
  'last_error': null,
  'created_at': '2026-10-07T10:00:00Z',
  'updated_at': '2026-10-07T10:00:00Z',
};

/// A `PrinterRead` body: a colour multifunction printer, online.
Map<String, Object?> printerBody({
  String id = 'printer-1',
  String name = 'Front desk',
  String? location = 'Second floor',
  String status = 'online',
  String organizationId = '0198c0de-0000-7000-8000-00000000000b',
  List<Map<String, Object?>>? connections,
  List<Map<String, Object?>> consumables = const [],
  List<Map<String, Object?>> alerts = const [],
  bool scans = true,
}) => {
  'id': id,
  'organization_id': organizationId,
  'friendly_name': name,
  'manufacturer': 'Xerox',
  'model': 'VersaLink C7130',
  'serial_number': null,
  'location': location,
  'status': status,
  'status_detail': {
    'alerts': alerts,
    'consumables': consumables,
    'scanner_state': scans ? 'idle' : 'unknown',
    'trays': <Object?>[],
  },
  'auto_fallback_enabled': true,
  'last_seen_at': '2026-10-07T10:00:00Z',
  'capabilities_updated_at': '2026-10-07T10:00:00Z',
  'default_connection_id': null,
  'connections':
      connections ??
      [
        connectionBody(printerId: id),
        connectionBody(
          type: 'escl',
          port: 80,
          path: '/eSCL',
          priority: 2,
          printerId: id,
        ),
      ],
  'capabilities': {
    'schema_version': 1,
    'print': {
      'supported': true,
      'color': true,
      'collation': true,
      'secure_print': false,
      'duplex_modes': ['one_sided', 'two_sided_long_edge'],
      'document_formats': ['application/pdf', 'image/jpeg'],
      'media_sizes': ['iso_a4_210x297mm', 'na_letter_8.5x11in'],
      'media_types': <String>[],
      'quality_modes': ['draft', 'normal', 'high'],
      'resolutions_dpi': [600, 1200],
      'finishing': <String>[],
      'max_copies': 999,
      'trays': [
        {
          'id': 'tray-1',
          'name': 'tray-1',
          'media_size': null,
          'media_type': null,
        },
      ],
    },
    'scan': {
      'supported': scans,
      'adf_duplex': scans,
      'sources': scans ? ['platen', 'adf'] : <String>[],
      'color_modes': scans ? ['color', 'grayscale'] : <String>[],
      'document_formats': scans
          ? ['application/pdf', 'image/jpeg']
          : <String>[],
      'resolutions_dpi': scans ? [300, 600] : <int>[],
      'max_width_mm': scans ? 216.0 : null,
      'max_height_mm': scans ? 297.0 : null,
    },
    'copy': {'supported': scans, 'native_remote_control': false},
    'status': {'reporting': true, 'consumables': true, 'trays': false},
    'protocols': {
      'ipp': true,
      'ipps': false,
      'escl': scans,
      'airprint': true,
      'mopria': null,
      'http_ews': null,
      'smb_scan': null,
      'snmp': null,
    },
    'connectivity': {
      'ethernet': null,
      'wifi': null,
      'wifi_direct': null,
      'usb': null,
      'nfc': null,
      'ble_beacon': null,
    },
  },
  'created_at': '2026-10-07T10:00:00Z',
  'updated_at': '2026-10-07T10:00:00Z',
};

/// A `CapabilityProfileRead` body: a family of printers in the catalogue.
Map<String, Object?> profileBody({
  String id = 'profile-1',
  String manufacturer = 'Xerox',
  String name = 'VersaLink C7100 Series',
  String category = 'office_multifunction',
  String? summary = 'A3 colour multifunction for a busy office.',
  int popularity = 100,
  List<String> setupTips = const [
    'Connect the printer to the office network.',
    'Switch on Mopria scanning in the printer’s web page.',
  ],
  bool color = true,
  bool scans = true,
}) => {
  'id': id,
  'manufacturer': manufacturer,
  'display_name': name,
  'category': category,
  'summary': summary,
  'popularity': popularity,
  'model_patterns': ['*'],
  'optional_features': <String>[],
  'notes': <String>[],
  'setup_tips': setupTips,
  'version': 1,
  'capabilities': {
    ...printerBody(scans: scans)['capabilities']! as Map<String, Object?>,
    'print': {
      ...(printerBody()['capabilities']! as Map<String, Object?>)['print']!
          as Map<String, Object?>,
      'color': color,
    },
  },
  'updated_at': '2026-10-07T10:00:00Z',
};

/// A `NotificationRead` body: a print that finished, not yet read.
Map<String, Object?> notificationBody({
  String id = 'notification-1',
  String type = 'job.completed',
  String title = 'Print finished',
  String body = 'Report.pdf was printed on Front desk.',
  Map<String, String> data = const {
    'job_id': 'job-1',
    'organization_id': 'org-1',
    'printer_id': 'printer-1',
    'job_type': 'print',
    'status': 'completed',
  },
  String? readAt,
  String createdAt = '2026-10-07T10:00:00Z',
}) => {
  'id': id,
  'organization_id': data['organization_id'],
  'type': type,
  'title': title,
  'body': body,
  'data': data,
  'read_at': readAt,
  'created_at': createdAt,
};

/// A `DocumentRead` body: a scan kept in the workspace's storage.
Map<String, Object?> documentBody({
  String id = 'document-1',
  String name = 'Receipts.pdf',
  String mimeType = 'application/pdf',
  int sizeBytes = 2048,
  int? pageCount = 3,
  String source = 'printer_scan',
  String storageMode = 'cloud',
  String uploadStatus = 'uploaded',
  String? printerId = 'printer-1',
  String createdAt = '2026-10-07T10:00:00Z',
}) => {
  'id': id,
  'organization_id': 'org-1',
  'owner_id': 'user-1',
  'file_name': name,
  'mime_type': mimeType,
  'size_bytes': sizeBytes,
  'page_count': pageCount,
  'source': source,
  'storage_mode': storageMode,
  'upload_status': uploadStatus,
  'checksum_sha256': null,
  'tags': <String>[],
  'has_ocr_text': false,
  'source_printer_id': printerId,
  'retention_expires_at': null,
  'created_at': createdAt,
  'updated_at': createdAt,
};

/// A `PresetRead` body: a print preset of the signed-in user's own.
Map<String, Object?> presetBody({
  String id = 'preset-1',
  String name = 'Handouts',
  String scope = 'personal',
  String? printerId,
  bool isDefault = false,
  int copies = 1,
  String duplex = 'two_sided_long_edge',
  String colorMode = 'auto',
  String? tray,
  String? mediaSize,
  String? quality,
}) => {
  'id': id,
  'organization_id': 'org-1',
  'owner_user_id': scope == 'personal' ? 'user-1' : null,
  'scope': scope,
  'name': name,
  'printer_id': printerId,
  'is_default': isDefault,
  'type': 'print',
  'settings': {
    'copies': copies,
    'color_mode': colorMode,
    'duplex': duplex,
    'page_ranges': null,
    'media_size': mediaSize,
    'media_type': null,
    'tray': tray,
    'orientation': 'auto',
    'scaling': 'fit',
    'scale_percent': null,
    'collate': true,
    'quality': quality,
    'finishing': <String>[],
    'secure_print': false,
  },
  'created_at': '2026-10-07T10:00:00Z',
  'updated_at': '2026-10-07T10:00:00Z',
};

/// A `JobRead` body: a print job.
Map<String, Object?> jobBody({
  String id = 'job-1',
  String status = 'queued',
  String? title = 'Report.pdf',
  String printerId = 'printer-1',
  String type = 'print',
  int copies = 1,
  String? connectionType,
  bool fallbackOccurred = false,
  String? errorCode,
  String? errorMessage,
  int? pageCount,
  String? retryOf,
  String submittedAt = '2026-10-07T10:00:00Z',
}) => {
  'id': id,
  'organization_id': 'org-1',
  'user_id': 'user-1',
  'printer_id': printerId,
  'device_id': null,
  'execution_mode': 'local',
  'type': type,
  'status': status,
  'title': title,
  'document_id': null,
  'output_document_id': null,
  'connection_id': null,
  'connection_type': connectionType,
  'fallback_occurred': fallbackOccurred,
  'retry_of_job_id': retryOf,
  'printer_job_ref': null,
  'error_code': errorCode,
  'error_message': errorMessage,
  'page_count': pageCount,
  'settings': switch (type) {
    'scan' => {
      'source': 'auto',
      'duplex': false,
      'color_mode': 'auto',
      'resolution_dpi': 300,
      'format': 'application/pdf',
      'media_size': null,
      'searchable_pdf': false,
    },
    'copy' => {
      'copies': copies,
      'color_mode': 'auto',
      'source_duplex': false,
      'output_duplex': 'one_sided',
      'media_size': null,
      'tray': null,
      'scaling': 'actual',
      'scale_percent': null,
      'collate': true,
      'method': 'scan_then_print',
    },
    _ => {
      'copies': copies,
      'color_mode': 'auto',
      'duplex': 'one_sided',
      'page_ranges': null,
      'media_size': null,
      'media_type': null,
      'tray': null,
      'orientation': 'auto',
      'scaling': 'fit',
      'scale_percent': null,
      'collate': true,
      'quality': null,
      'finishing': <String>[],
      'secure_print': false,
    },
  },
  'submitted_at': submittedAt,
  'started_at': null,
  'completed_at': const {'completed', 'failed', 'cancelled'}.contains(status)
      ? '2026-10-07T10:01:00Z'
      : null,
  'created_at': submittedAt,
  'updated_at': submittedAt,
};
