import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:local_store/local_store.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:printer_discovery/testing.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:printerhub/printers/finders.dart';
import 'package:printers_repository/printers_repository.dart';

/// A pretend PrinterHub API with the real client and repositories on top,
/// so a test exercises everything from the screen down to the request.
///
/// It behaves like a healthy backend for one user. Change [user] and
/// [organizations] to set the scene, put a handler in [routes] to make one
/// endpoint misbehave, or set [offline].
class TestBackend {
  new() {
    network = FakeApi(_answer);
    client = PrinterHubClient(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: SecureTokenStore(store),
      httpClientAdapter: network,
    );
    auth = AuthRepository(
      client: client,
      store: store,
      describePhone: () async => const PhoneDetails(
        platform: 'ios',
        model: 'iPhone 15 Pro',
        osVersion: 'iOS 18.1',
        appVersion: '1.0.0 (1)',
      ),
    );
    organizations = OrganizationsRepository(client: client, store: store);
    device = FakePrinterHttp(
      (request) => throw PrinterUnreachable(request.uri, 'nothing there'),
    );
    printers = PrintersRepository(
      client: client,
      probe: DeviceProbe(http: device),
      store: store,
    );
    finders = PrinterFinders(
      network: nearby,
      nfc: nfc,
      bluetooth: bluetooth,
      wifi: wifi,
      qrScanner: (onCode) {
        _onCode = onCode;
        return const SizedBox(key: qrCameraKey);
      },
    );
  }

  /// Marks the stand-in for the camera, so a test can see it is shown.
  static const Key qrCameraKey = Key('qr-camera');

  final InMemorySecureStore store = InMemorySecureStore();
  late final FakeApi network;
  late final PrinterHubClient client;
  late final AuthRepository auth;
  late final OrganizationsRepository organizations;
  late final PrintersRepository printers;

  /// The local network. Nothing answers on it until [plugInPrinter].
  late final FakePrinterHttp device;

  /// What the phone's radios find. Nothing, until a test says otherwise.
  final FakeNetworkDiscovery nearby = FakeNetworkDiscovery();
  final FakeNfcReader nfc = FakeNfcReader();
  final FakeBluetoothScanner bluetooth = FakeBluetoothScanner();
  final FakeWifiNetwork wifi = FakeWifiNetwork();
  late final PrinterFinders finders;
  late ValueChanged<String> _onCode;

  /// Shows [text] to the camera, as a QR code. The scanning step has to be
  /// on screen.
  void scanCode(String text) => _onCode(text);

  /// The printers the API knows, in every workspace.
  List<Map<String, Object?>> printerList = [];

  /// The catalogue of printer families.
  List<Map<String, Object?>> families = [
    profileBody(),
    profileBody(
      id: 'profile-2',
      manufacturer: 'HP',
      name: 'DeskJet, ENVY, and Smart Tank',
      category: 'home_multifunction',
      summary: 'Wi-Fi inkjets for the home that print, copy, and scan.',
      popularity: 95,
      setupTips: const ['Wake the printer before you look for it.'],
    ),
    profileBody(
      id: 'profile-3',
      manufacturer: 'Brother',
      name: 'HL-L lasers',
      category: 'office_printer',
      summary: 'Compact laser printers for the desk.',
      popularity: 80,
      setupTips: const [],
      color: false,
      scans: false,
    ),
  ];

  /// Where the account is signed in. The first is this phone.
  List<Map<String, Object?>> sessionList = [
    _sessionBody('session-1', current: true, deviceId: 'device-1'),
    _sessionBody('session-2', userAgent: 'PrinterHub/1.0 Android'),
  ];

  /// The phones the account has been used on. A phone that registers is
  /// added, or replaces the one with its installation id.
  List<Map<String, Object?>> deviceList = [
    _deviceBody('device-2', model: 'Pixel 8', platform: 'android'),
  ];

  static Map<String, Object?> _sessionBody(
    String id, {
    bool current = false,
    String? deviceId,
    String? userAgent,
  }) => {
    'id': id,
    'device_id': deviceId,
    'user_agent': userAgent,
    'ip': '203.0.113.7',
    'is_current': current,
    'created_at': '2026-10-01T10:00:00Z',
    'last_used_at': '2026-10-07T10:00:00Z',
    'expires_at': '2026-11-01T10:00:00Z',
  };

  static Map<String, Object?> _deviceBody(
    String id, {
    required String model,
    String platform = 'ios',
    String installationId = 'another-install',
    String? osVersion = 'Android 15',
    bool pushEnabled = true,
  }) => {
    'id': id,
    'installation_id': installationId,
    'platform': platform,
    'name': null,
    'model': model,
    'os_version': osVersion,
    'app_version': '1.0.0 (1)',
    'push_provider': pushEnabled ? 'fcm' : null,
    'push_enabled': pushEnabled,
    'last_seen_at': '2026-10-07T10:00:00Z',
    'created_at': '2026-10-01T10:00:00Z',
  };

  /// The user name and password saved with each printer that was added with
  /// one, by printer id.
  final Map<String, Map<String, dynamic>> printerPasswords = {};

  /// The account the API knows.
  Map<String, Object?> user = userBody();

  /// The workspaces that account belongs to.
  List<Map<String, Object?>> workspaces = [];

  /// Handlers by `'METHOD /path'`, without the `/api/v1` prefix. They take
  /// the place of the default answer.
  final Map<String, FakeHandler> routes = {};

  /// When true every request fails as if there were no connection.
  bool offline = false;

  /// The requests sent to `'METHOD /path'`.
  List<RequestOptions> sent(String route) {
    return network.requests.where((request) => _key(request) == route).toList();
  }

  /// The JSON body of the last request to `'METHOD /path'`.
  Map<String, dynamic> lastBody(String route) {
    return jsonDecode(jsonEncode(sent(route).last.data))
        as Map<String, dynamic>;
  }

  /// Makes one endpoint answer with an API error.
  void fail(String route, int status, String code, {String? detail}) {
    routes[route] = (_) async =>
        FakeResponse.problem(status, code, detail: detail);
  }

  /// Puts a session from an earlier launch on the device, as bootstrap
  /// would find it.
  ///
  /// Inside `testWidgets`, call it through `tester.runAsync`, or from
  /// `setUp`: a request awaited directly under the fake clock never ends.
  Future<void> signedInBefore({bool withWorkspace = true}) async {
    if (withWorkspace && workspaces.isEmpty) workspaces = [organizationBody()];
    await auth.signIn(email: 'ada@example.com', password: 'correct horse');
    if (workspaces.isNotEmpty) await organizations.list();
    network.requests.clear();
  }

  /// Puts a colour multifunction printer on the local network, answering
  /// IPP and eSCL at any address. [stateReasons] and [tonerLevels] set what
  /// it reports about itself.
  ///
  /// With [signIn], it prints only for that user name and password, as a
  /// printer with IPP authentication switched on does.
  void plugInPrinter({
    List<String> stateReasons = const ['none'],
    Map<String, int> tonerLevels = const {'black': 82, 'cyan': 8},
    PrinterCredentials? signIn,
  }) {
    device.device = (request) {
      if (request.uri.path.endsWith('ScannerStatus')) {
        return FakeAnswer.text(200, _scannerStatus);
      }
      if (request.uri.path.contains('eSCL')) {
        return FakeAnswer.text(200, _scannerCapabilities);
      }
      if (signIn != null && !_signedIn(request, signIn)) {
        return const FakeAnswer(
          401,
          headers: {'www-authenticate': 'Digest realm="Printer", nonce="n1"'},
        );
      }
      return FakeAnswer.ipp(
        ippResponse(
          groups: [
            IppGroup(IppGroupTag.printer, [
              IppAttribute.single(
                'printer-make-and-model',
                IppValueTag.text,
                'Xerox VersaLink C7130',
              ),
              IppAttribute.single('printer-state', IppValueTag.enumeration, 3),
              IppAttribute.all(
                'printer-state-reasons',
                IppValueTag.keyword,
                stateReasons,
              ),
              IppAttribute.single('color-supported', IppValueTag.boolean, true),
              IppAttribute.all('sides-supported', IppValueTag.keyword, const [
                'one-sided',
                'two-sided-long-edge',
              ]),
              IppAttribute.all('marker-names', IppValueTag.name, [
                for (final color in tonerLevels.keys)
                  '${color[0].toUpperCase()}${color.substring(1)} Toner',
              ]),
              IppAttribute.all('marker-types', IppValueTag.keyword, [
                for (final _ in tonerLevels.keys) 'toner',
              ]),
              IppAttribute.all(
                'marker-colors',
                IppValueTag.name,
                tonerLevels.keys,
              ),
              IppAttribute.all(
                'marker-levels',
                IppValueTag.integer,
                tonerLevels.values,
              ),
            ]),
          ],
        ),
      );
    };
  }

  /// Whether [request] is signed the way [expected] would sign it.
  static bool _signedIn(SentRequest request, PrinterCredentials expected) {
    return request.headers['Authorization'] ==
        const AuthChallenge(
          digest: true,
          realm: 'Printer',
          nonce: 'n1',
        ).authorize(expected, method: request.method, uri: request.uri);
  }

  /// Takes the printer off the network again.
  void unplugPrinter() {
    device.device = (request) =>
        throw PrinterUnreachable(request.uri, 'nothing there');
  }

  Future<void> close() async {
    await auth.close();
    await client.close();
  }

  static String _key(RequestOptions request) {
    return '${request.method} ${request.path.replaceFirst('/api/v1', '')}';
  }

  Future<FakeResponse> _answer(RequestOptions request) async {
    if (offline) throw const FormatException('offline');

    final key = _key(request);
    final custom = routes[key];
    if (custom != null) return await custom(request);

    final body = request.data is Map
        ? jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>
        : const <String, dynamic>{};
    final session = {
      'user': user,
      'tokens': tokenResponse('access', 'refresh'),
    };

    switch (key) {
      case 'POST /auth/login':
        return FakeResponse(200, session);
      case 'POST /auth/register':
        user = {...user, 'name': body['name'], 'email': body['email']};
        return FakeResponse(201, {...session, 'user': user});
      case 'GET /users/me':
        return FakeResponse(200, user);
      case 'PATCH /users/me':
        user = {
          ...user,
          if (body['name'] != null) 'name': body['name'],
          if (body['preferences'] != null)
            'preferences': {
              ...user['preferences']! as Map<String, Object?>,
              ...body['preferences'] as Map<String, dynamic>,
            },
        };
        return FakeResponse(200, user);
      case 'POST /auth/email/verify':
        user = {...user, 'email_verified_at': '2026-10-07T11:00:00Z'};
        return FakeResponse(200, user);
      case 'GET /organizations':
        return FakeResponse(200, workspaces);
      case 'POST /organizations':
        final created = organizationBody(
          id: 'org-${workspaces.length + 1}',
          name: body['name'] as String,
        );
        workspaces = [...workspaces, created];
        return FakeResponse(201, created);
      case 'POST /pairing/redeem':
        final printer = printerList
            .where((item) => 'token-${item['id']}' == body['token'])
            .firstOrNull;
        return printer == null
            ? FakeResponse.problem(422, 'pairing.token_invalid')
            : FakeResponse(200, {'printer': printer});
      case 'GET /capability-profiles':
        return FakeResponse(200, families);
      case 'GET /capability-profiles/match':
        final maker = '${request.queryParameters['manufacturer']}'
            .toLowerCase();
        final family = families
            .where((item) => '${item['manufacturer']}'.toLowerCase() == maker)
            .firstOrNull;
        return family == null
            ? FakeResponse.problem(404, 'capability_profile.no_match')
            : FakeResponse(200, family);
      case 'GET /auth/sessions':
        return FakeResponse(200, sessionList);
      case 'GET /devices':
        return FakeResponse(200, deviceList);
      case 'POST /devices':
        final registered = _deviceBody(
          'device-1',
          model: body['model'] as String? ?? 'iPhone',
          installationId: body['installation_id'] as String,
          osVersion: body['os_version'] as String?,
          pushEnabled: body['push_token'] != null,
        );
        deviceList = [
          registered,
          for (final device in deviceList)
            if (device['id'] != 'device-1') device,
        ];
        return FakeResponse(200, registered);
      case 'POST /auth/logout' ||
          'POST /auth/email/resend' ||
          'POST /auth/password/forgot' ||
          'POST /auth/password/reset' ||
          'POST /auth/password/change' ||
          'POST /account/delete':
        return const FakeResponse(204);
    }
    final removal = _removalRoute.firstMatch(key);
    if (removal != null) {
      final id = removal.group(2);
      if (removal.group(1) == 'auth/sessions') {
        sessionList = [
          for (final session in sessionList)
            if (session['id'] != id) session,
        ];
      } else {
        deviceList = [
          for (final device in deviceList)
            if (device['id'] != id) device,
        ];
      }
      return const FakeResponse(204);
    }
    final credentialsRoute = _credentialsRoute.firstMatch(key);
    if (credentialsRoute != null) {
      final secrets = printerPasswords[credentialsRoute.group(1)];
      return secrets == null
          ? FakeResponse.problem(404, 'connection.not_found')
          : FakeResponse(200, {...secrets, 'extra': <String, String>{}});
    }
    final printerRoute = _printerRoute.firstMatch(key);
    if (printerRoute != null) return _answerPrinters(printerRoute, body);

    return FakeResponse.problem(404, 'not_found', detail: 'No route for $key');
  }

  static final RegExp _removalRoute = RegExp(
    r'^DELETE /(auth/sessions|devices)/([^/]+)$',
  );

  static final RegExp _credentialsRoute = RegExp(
    r'^GET /organizations/[^/]+/printers/([^/]+)/connections/[^/]+/credentials$',
  );

  static final RegExp _printerRoute = RegExp(
    '^(GET|POST|PATCH|DELETE) /organizations/([^/]+)/printers'
    r'(?:/([^/]+))?(/status|/pairing-tokens)?$',
  );

  FakeResponse _answerPrinters(RegExpMatch route, Map<String, dynamic> body) {
    final method = route.group(1)!;
    final organizationId = route.group(2)!;
    final printerId = route.group(3);
    final isStatus = route.group(4) == '/status';
    if (route.group(4) == '/pairing-tokens') {
      // The token is the printer's id with a prefix, so a test can read it.
      return FakeResponse(201, {
        'payload': {
          'v': 1,
          'token': 'token-$printerId',
          'printer_id': printerId,
          'organization_id': organizationId,
        },
        'deep_link': 'printerhub://pair?token=token-$printerId',
        'expires_at': '2026-10-07T10:05:00Z',
      });
    }
    int indexOf(String id) => printerList.indexWhere((p) => p['id'] == id);

    if (printerId == null) {
      if (method == 'GET') {
        return FakeResponse(200, {
          'items': [
            for (final printer in printerList)
              if (printer['organization_id'] == organizationId) printer,
          ],
          'next_cursor': null,
        });
      }
      final id = 'printer-${printerList.length + 1}';
      final sent = (body['connections'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final secrets = sent
          .map((connection) => connection['credentials'])
          .whereType<Map<String, dynamic>>()
          .firstOrNull;
      final created = printerBody(
        id: id,
        name: body['friendly_name'] as String,
        location: body['location'] as String?,
        organizationId: organizationId,
        scans: (body['capabilities'] as Map<String, dynamic>).containsKey(
          'scan',
        ),
        connections: secrets == null
            ? null
            : [connectionBody(printerId: id, hasCredentials: true)],
      );
      if (secrets != null) printerPasswords[id] = secrets;
      printerList = [...printerList, created];
      return FakeResponse(201, created);
    }

    final index = indexOf(printerId);
    if (index < 0) return FakeResponse.problem(404, 'printer.not_found');
    if (method == 'DELETE') {
      printerList = [...printerList]..removeAt(index);
      return const FakeResponse(204);
    }

    final detail = body['detail'] as Map<String, dynamic>?;
    final updated = {
      ...printerList[index],
      if (body['friendly_name'] != null) 'friendly_name': body['friendly_name'],
      if (isStatus) 'status': body['status'],
      if (isStatus && detail != null)
        'status_detail': {
          'alerts': [
            for (final alert in detail['alerts'] as List<dynamic>? ?? [])
              {...alert as Map<String, dynamic>, 'message': null},
          ],
          'consumables': [
            for (final item in detail['consumables'] as List<dynamic>? ?? [])
              {
                'color': null,
                'level_percent': null,
                ...item as Map<String, dynamic>,
              },
          ],
          'scanner_state': detail['scanner_state'] ?? 'unknown',
          'trays': <Object?>[],
        },
    };
    printerList = [...printerList]..[index] = updated;
    return FakeResponse(200, updated);
  }
}

const _escl =
    'xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" '
    'xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm"';

const _scannerStatus =
    '<scan:ScannerStatus $_escl><pwg:State>Idle</pwg:State></scan:ScannerStatus>';

final String _scannerCapabilities = [
  '<scan:ScannerCapabilities $_escl>',
  '<pwg:MakeAndModel>Xerox VersaLink C7130</pwg:MakeAndModel>',
  '<scan:Platen><scan:PlatenInputCaps>',
  '<scan:MaxWidth>2550</scan:MaxWidth><scan:MaxHeight>3508</scan:MaxHeight>',
  '<scan:ColorMode>RGB24</scan:ColorMode>',
  '<pwg:DocumentFormat>application/pdf</pwg:DocumentFormat>',
  '<scan:XResolution>300</scan:XResolution>',
  '</scan:PlatenInputCaps></scan:Platen>',
  '<scan:Adf><scan:AdfSimplexInputCaps>',
  '<scan:ColorMode>RGB24</scan:ColorMode>',
  '</scan:AdfSimplexInputCaps></scan:Adf>',
  '</scan:ScannerCapabilities>',
].join();
