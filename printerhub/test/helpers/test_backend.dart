import 'dart:convert';
import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:api_client/testing.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:documents_repository/documents_repository.dart';
import 'package:documents_repository/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:local_store/local_store.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:printer_discovery/testing.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printer_protocols/testing.dart';
import 'package:printerhub/print/print.dart';
import 'package:printerhub/printers/finders.dart';
import 'package:printers_repository/printers_repository.dart';

import 'fake_documents.dart';

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
      // Followed without sitting through a print. The pause is short but
      // real: with none, a job that stays on the printer would spin without
      // ever letting a test's clock move on.
      runner: PrintRunner(
        http: device,
        pause: (_) => Future<void>.delayed(const Duration(milliseconds: 10)),
      ),
      scanner: ScanRunner(
        http: device,
        directory: scans,
        pause: (_) => Future<void>.delayed(const Duration(milliseconds: 10)),
      ),
      store: store,
    );
    jobs = JobsRepository(client: client, store: store);
    presets = PresetsRepository(client: client);
    notifications = NotificationsRepository(client: client);
    documentsKept = DocumentsRepository(
      client: client,
      transfer: storage,
      directory: scans,
    );
    documents = PrintDocuments(picker: picker, renderer: renderer);
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

  /// Where scanned pages are kept. Deleted by [close].
  final Directory scans = Directory.systemTemp.createTempSync('test_backend');
  late final FakeApi network;
  late final PrinterHubClient client;
  late final AuthRepository auth;
  late final OrganizationsRepository organizations;
  late final PrintersRepository printers;
  late final JobsRepository jobs;
  late final PresetsRepository presets;

  /// The people in the workspace, the invitations it has sent, and the
  /// ones the signed-in person was sent.
  List<Map<String, Object?>> memberList = [
    memberBody(userId: '0198c0de-0000-7000-8000-000000000002', name: 'Ada'),
    memberBody(
      userId: 'user-2',
      name: 'Grace Hopper',
      email: 'grace@example.com',
      role: 'user',
    ),
  ];
  List<Map<String, Object?>> invitationList = [];
  List<Map<String, Object?>> receivedInvitations = [];

  /// What the workspace's log records, newest first, and how many it
  /// gives at a time.
  List<Map<String, Object?>> auditList = [];
  int auditPageSize = 20;

  /// What is switched on for the workspace.
  Map<String, bool> features = {};

  /// What the account has been told, newest first.
  late final NotificationsRepository notifications;
  List<Map<String, Object?>> notificationList = [];

  /// How many notifications the list gives at a time.
  int notificationPageSize = 20;

  /// The documents the workspace keeps, and the storage their files are in.
  late final DocumentsRepository documentsKept;
  final FakeFileTransfer storage = FakeFileTransfer();
  List<Map<String, Object?>> documentList = [];

  /// How many documents the list gives at a time.
  int documentPageSize = 20;

  /// The phone's file browser and its PDF and image code.
  final FakeDocumentPicker picker = FakeDocumentPicker();
  final FakePageRenderer renderer = FakePageRenderer();
  late PrintDocuments documents;

  /// The jobs the backend has on record, newest first, and what happened
  /// to each, by job id.
  List<Map<String, Object?>> jobList = [];
  final Map<String, List<Map<String, dynamic>>> jobEvents = {};

  /// How many jobs the history gives at a time.
  int jobPageSize = 20;

  /// The saved settings the backend has, the signed-in user's own and the
  /// workspace's.
  List<Map<String, Object?>> presetList = [];

  /// What the plugged-in printer was sent to print, with each request's
  /// attributes.
  final List<IppDecoded> printed = [];

  /// The state the printer reports for a job it is asked about: 9 is
  /// completed, 5 printing, 6 stopped, 7 cancelled, 8 given up on.
  int printerJobState = 9;

  /// The IPP status the printer answers Validate-Job with, when not OK.
  int? printerRefuses;

  /// The pages the plugged-in scanner gives a scan, each a picture.
  List<List<int>> scanPages = [tinyJpeg];

  /// The settings of each scan the scanner was asked for.
  final List<String> scansStarted = [];

  /// The HTTP status the scanner answers a new scan with, when not 201.
  int? scannerRefuses;

  /// What the scanner says of its feeder.
  String scannerFeeder = 'ScannerAdfLoaded';

  /// The phone's share sheet.
  final FakeScanSharer sharer = FakeScanSharer();

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
    List<String> formats = const ['application/pdf', 'image/pwg-raster'],
  }) {
    var served = 0;
    device.device = (request) {
      final path = request.uri.path;
      if (path.endsWith('ScannerStatus')) {
        return FakeAnswer.text(200, _scannerStatus(scannerFeeder));
      }
      if (path.endsWith('/ScanJobs')) {
        scansStarted.add(String.fromCharCodes(request.body));
        served = 0;
        final refused = scannerRefuses;
        return refused != null
            ? FakeAnswer(refused)
            : const FakeAnswer(201, headers: {'location': '/eSCL/ScanJobs/1'});
      }
      if (path.endsWith('/NextDocument')) {
        if (served >= scanPages.length) return const FakeAnswer(404);
        return FakeAnswer(
          200,
          body: scanPages[served++],
          headers: const {'content-type': 'image/jpeg'},
        );
      }
      if (path.contains('/ScanJobs/')) return const FakeAnswer(200);
      if (path.contains('eSCL')) {
        return FakeAnswer.text(200, _scannerCapabilities);
      }
      if (signIn != null && !_signedIn(request, signIn)) {
        return const FakeAnswer(
          401,
          headers: {'www-authenticate': 'Digest realm="Printer", nonce="n1"'},
        );
      }
      final asked = decodeIpp(request.body);
      final jobReply = _answerPrintJob(asked);
      if (jobReply != null) return jobReply;
      return FakeAnswer.ipp(
        ippResponse(
          groups: [
            IppGroup(IppGroupTag.printer, [
              IppAttribute.all(
                'document-format-supported',
                IppValueTag.mimeMediaType,
                formats,
              ),
              IppAttribute.all(
                'pwg-raster-document-type-supported',
                IppValueTag.keyword,
                const ['sgray_8', 'srgb_8'],
              ),
              IppAttribute.single(
                'pwg-raster-document-resolution-supported',
                IppValueTag.resolution,
                const IppResolution(300, 300),
              ),
              IppAttribute.all('media-supported', IppValueTag.keyword, const [
                'iso_a4_210x297mm',
                'na_letter_8.5x11in',
              ]),
              IppAttribute.single(
                'copies-supported',
                IppValueTag.rangeOfInteger,
                const IppRange(1, 999),
              ),
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

  /// The printer's answer to an operation on a job, or null for a question
  /// about the printer itself.
  FakeAnswer? _answerPrintJob(IppDecoded asked) {
    IppGroup job({String? name}) => IppGroup(IppGroupTag.job, [
      IppAttribute.single('job-id', IppValueTag.integer, 1),
      IppAttribute.single(
        'job-state',
        IppValueTag.enumeration,
        printerJobState,
      ),
      if (name != null) IppAttribute.single('job-name', IppValueTag.name, name),
      if (printerJobState == 6)
        IppAttribute.single(
          'job-state-reasons',
          IppValueTag.keyword,
          'media-empty-error',
        ),
    ]);

    switch (asked.message.code) {
      case IppOperation.getPrinterAttributes:
        return null;
      case IppOperation.validateJob:
        return FakeAnswer.ipp(
          ippResponse(status: printerRefuses ?? IppStatus.ok),
        );
      case IppOperation.printJob:
        printed.add(asked);
        return FakeAnswer.ipp(ippResponse(groups: [job()]));
      case IppOperation.cancelJob:
        printerJobState = 7;
        return FakeAnswer.ipp(ippResponse());
      case IppOperation.getJobs:
        return FakeAnswer.ipp(
          ippResponse(
            groups: [
              for (final sent in printed)
                job(
                  name:
                      sent.message
                              .group(IppGroupTag.operation)!['job-name']!
                              .first!
                          as String,
                ),
            ],
          ),
        );
      default:
        return FakeAnswer.ipp(ippResponse(groups: [job()]));
    }
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
    if (scans.existsSync()) scans.deleteSync(recursive: true);
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
    final teamRoute = _teamRoute.firstMatch(key);
    if (teamRoute != null) {
      return _answerTeam(teamRoute, body, request.uri.queryParameters);
    }
    final notificationRoute = _notificationRoute.firstMatch(key);
    if (notificationRoute != null) {
      return _answerNotifications(
        notificationRoute,
        request.uri.queryParameters,
      );
    }
    final documentRoute = _documentRoute.firstMatch(key);
    if (documentRoute != null) {
      return _answerDocuments(documentRoute, body, request.uri.queryParameters);
    }
    final presetRoute = _presetRoute.firstMatch(key);
    if (presetRoute != null) return _answerPresets(presetRoute, body);
    final jobRoute = _jobRoute.firstMatch(key);
    if (jobRoute != null) {
      return _answerJobs(jobRoute, body, request.uri.queryParametersAll);
    }
    final connectionRoute = _connectionRoute.firstMatch(key);
    if (connectionRoute != null) {
      return _answerConnections(connectionRoute, body);
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
    '^(GET|POST|PUT|PATCH|DELETE) /organizations/([^/]+)/printers'
    r'(?:/([^/]+))?(/status|/pairing-tokens|/capabilities)?$',
  );

  static final RegExp _teamRoute = RegExp(
    '^(GET|POST|PATCH|DELETE) (?:/organizations/([^/]+)'
    '(?:(/members|/invitations|/audit-logs|/feature-flags)(?:/([^/]+))?)?'
    r'|/invitations(?:/([^/]+))?(?:/accept)?)$',
  );

  /// A workspace and its people: its rules, its members, the invitations
  /// it sends and the ones the signed-in person takes up, and its log.
  FakeResponse _answerTeam(
    RegExpMatch route,
    Map<String, dynamic> body,
    Map<String, String> query,
  ) {
    final method = route.group(1)!;
    final organizationId = route.group(2);
    final part = route.group(3);
    final id = route.group(4);

    if (organizationId == null) {
      // The invitations the signed-in person was sent.
      if (method == 'GET') return FakeResponse(200, receivedInvitations);
      final wanted = route.group(5);
      final invitation = receivedInvitations
          .where(
            (one) => wanted == 'accept'
                ? body['token'] == 'code-${one['id']}'
                : one['id'] == wanted,
          )
          .firstOrNull;
      if (invitation == null) {
        return FakeResponse.problem(
          404,
          'invitation.not_found',
          detail: 'That invitation is no longer open.',
        );
      }
      final joined = organizationBody(
        id: invitation['organization_id']! as String,
        name: invitation['organization_name']! as String,
        role: invitation['role']! as String,
      );
      receivedInvitations = [
        for (final one in receivedInvitations)
          if (one != invitation) one,
      ];
      workspaces = [...workspaces, joined];
      return FakeResponse(200, joined);
    }

    final index = workspaces.indexWhere((one) => one['id'] == organizationId);
    if (index < 0) return FakeResponse.problem(404, 'organization.not_found');
    switch (part) {
      case '/members' when id == null:
        return FakeResponse(200, memberList);
      case '/members':
        final member = memberList.indexWhere(
          (one) => (one['user']! as Map)['id'] == id,
        );
        if (method == 'DELETE') {
          memberList = [...memberList]..removeAt(member);
          if (id == user['id']) {
            workspaces = [...workspaces]..removeAt(index);
          }
          return const FakeResponse(204);
        }
        final changed = {...memberList[member], 'role': body['role']};
        memberList = [...memberList]..[member] = changed;
        return FakeResponse(200, changed);
      case '/invitations' when method == 'POST':
        final sent = invitationBody(
          id: 'invitation-${invitationList.length + 1}',
          email: body['email'] as String,
          role: body['role'] as String,
        );
        invitationList = [...invitationList, sent];
        return FakeResponse(201, {...sent, 'token': 'code-${sent['id']}'});
      case '/invitations' when method == 'DELETE':
        invitationList = [
          for (final one in invitationList)
            if (one['id'] != id) one,
        ];
        return const FakeResponse(204);
      case '/invitations':
        return FakeResponse(200, invitationList);
      case '/audit-logs':
        final from = int.parse(query['cursor'] ?? '0');
        final to = from + auditPageSize;
        return FakeResponse(200, {
          'items': auditList.skip(from).take(auditPageSize).toList(),
          'next_cursor': to < auditList.length ? '$to' : null,
        });
      case '/feature-flags':
        return FakeResponse(200, {'flags': features});
    }
    switch (method) {
      case 'DELETE':
        workspaces = [...workspaces]..removeAt(index);
        return const FakeResponse(204);
      case 'PATCH':
        final changed = {
          ...workspaces[index],
          if (body['name'] != null) 'name': body['name'],
          if (body['settings'] != null)
            'settings': {
              ...workspaces[index]['settings']! as Map<String, Object?>,
              // A rule left out is one that is not set.
              'max_copies_per_job': null,
              ...body['settings'] as Map<String, dynamic>,
            },
        };
        workspaces = [...workspaces]..[index] = changed;
        return FakeResponse(200, changed);
      default:
        return FakeResponse(200, workspaces[index]);
    }
  }

  static final RegExp _notificationRoute = RegExp(
    r'^(GET|POST) /notifications(?:/([^/]+))?(/read)?$',
  );

  /// What the account was told: listing it, counting the unread, and
  /// marking it read.
  FakeResponse _answerNotifications(
    RegExpMatch route,
    Map<String, String> query,
  ) {
    final id = route.group(2);
    const now = '2026-10-07T11:00:00Z';
    if (id == null) {
      final wanted = [
        for (final one in notificationList)
          if (query['unread_only'] != 'true' || one['read_at'] == null) one,
      ];
      final from = int.parse(query['cursor'] ?? '0');
      final to = from + notificationPageSize;
      return FakeResponse(200, {
        'items': wanted.skip(from).take(notificationPageSize).toList(),
        'next_cursor': to < wanted.length ? '$to' : null,
      });
    }
    if (id == 'unread-count') {
      return FakeResponse(200, {
        'unread': notificationList
            .where((one) => one['read_at'] == null)
            .length,
      });
    }
    if (id == 'read-all') {
      notificationList = [
        for (final one in notificationList)
          {...one, 'read_at': one['read_at'] ?? now},
      ];
      return const FakeResponse(204);
    }
    final index = notificationList.indexWhere((one) => one['id'] == id);
    if (index < 0) return FakeResponse.problem(404, 'notification.not_found');
    final read = {...notificationList[index], 'read_at': now};
    notificationList = [...notificationList]..[index] = read;
    return FakeResponse(200, read);
  }

  static final RegExp _documentRoute = RegExp(
    '^(GET|POST|PATCH|DELETE) /organizations/[^/]+/documents'
    r'(?:/([^/]+))?(/complete-upload|/upload-url|/download-url)?$',
  );

  /// The workspace's documents: making a record, sending its file to the
  /// storage, and listing, renaming, fetching, and deleting what is kept.
  FakeResponse _answerDocuments(
    RegExpMatch route,
    Map<String, dynamic> body,
    Map<String, String> query,
  ) {
    final method = route.group(1)!;
    final documentId = route.group(2);
    final action = route.group(3);
    Map<String, Object?> link(String id) => {
      'url': 'https://storage.example.com/$id?signature=abc',
      'method': 'PUT',
      'headers': <String, String>{},
      'expires_at': '2026-10-07T10:15:00Z',
    };

    if (documentId == null) {
      if (method == 'POST') {
        final created = documentBody(
          id: body['id'] as String,
          name: body['file_name'] as String,
          mimeType: body['mime_type'] as String,
          sizeBytes: body['size_bytes'] as int,
          pageCount: body['page_count'] as int?,
          printerId: body['source_printer_id'] as String?,
          uploadStatus: 'pending',
        );
        documentList = [created, ...documentList];
        return FakeResponse(201, {
          ...created,
          'upload': link(body['id'] as String),
        });
      }
      final wanted = (query['q'] ?? '').toLowerCase();
      final matching = [
        for (final document in documentList)
          if ((document['file_name']! as String).toLowerCase().contains(wanted))
            document,
      ];
      final from = int.parse(query['cursor'] ?? '0');
      final to = from + documentPageSize;
      return FakeResponse(200, {
        'items': matching.skip(from).take(documentPageSize).toList(),
        'next_cursor': to < matching.length ? '$to' : null,
      });
    }

    final index = documentList.indexWhere((d) => d['id'] == documentId);
    if (index < 0) return FakeResponse.problem(404, 'document.not_found');
    final document = documentList[index];
    switch (action) {
      case '/upload-url':
        return FakeResponse(200, link(documentId));
      case '/download-url':
        if (document['upload_status'] != 'uploaded') {
          return FakeResponse.problem(409, 'document.upload_incomplete');
        }
        return FakeResponse(200, {
          'url': 'https://storage.example.com/$documentId?signature=down',
          'expires_at': '2026-10-07T10:15:00Z',
        });
      case '/complete-upload':
        if (!storage.stored.containsKey('/$documentId')) {
          return FakeResponse.problem(409, 'document.upload_missing');
        }
        final uploaded = {...document, 'upload_status': 'uploaded'};
        documentList = [...documentList]..[index] = uploaded;
        return FakeResponse(200, uploaded);
    }
    switch (method) {
      case 'DELETE':
        documentList = [...documentList]..removeAt(index);
        return const FakeResponse(204);
      case 'PATCH':
        final renamed = {...document, 'file_name': body['file_name']};
        documentList = [...documentList]..[index] = renamed;
        return FakeResponse(200, renamed);
      default:
        return FakeResponse(200, document);
    }
  }

  static final RegExp _presetRoute = RegExp(
    r'^(GET|POST|PATCH|DELETE) /organizations/[^/]+/presets(?:/([^/]+))?$',
  );

  /// Saved settings: listing, saving, changing, and deleting them. One
  /// preset at most is the default, as on the backend.
  FakeResponse _answerPresets(RegExpMatch route, Map<String, dynamic> body) {
    final method = route.group(1)!;
    final presetId = route.group(2);

    void onlyDefault(Map<String, Object?> preset) {
      if (preset['is_default'] != true) return;
      presetList = [
        for (final other in presetList)
          if (other['id'] == preset['id'])
            other
          else
            {...other, 'is_default': false},
      ];
    }

    if (presetId == null) {
      if (method == 'GET') {
        return FakeResponse(
          200,
          [...presetList]..sort(
            (a, b) => (a['name']! as String).compareTo(b['name']! as String),
          ),
        );
      }
      final settings = body['settings'] as Map<String, dynamic>? ?? const {};
      final created = presetBody(
        id: 'preset-${presetList.length + 1}',
        name: body['name'] as String,
        scope: body['scope'] as String,
        printerId: body['printer_id'] as String?,
        isDefault: body['is_default'] as bool,
        copies: settings['copies'] as int? ?? 1,
        duplex: settings['duplex'] as String? ?? 'one_sided',
        colorMode: settings['color_mode'] as String? ?? 'auto',
        tray: settings['tray'] as String?,
        mediaSize: settings['media_size'] as String?,
        quality: settings['quality'] as String?,
      );
      presetList = [...presetList, created];
      onlyDefault(created);
      return FakeResponse(201, created);
    }

    final index = presetList.indexWhere((preset) => preset['id'] == presetId);
    if (index < 0) return FakeResponse.problem(404, 'preset.not_found');
    switch (method) {
      case 'DELETE':
        presetList = [...presetList]..removeAt(index);
        return const FakeResponse(204);
      case 'PATCH':
        final changed = {
          ...presetList[index],
          if (body['name'] != null) 'name': body['name'],
          if (body['is_default'] != null) 'is_default': body['is_default'],
          if (body['settings'] != null)
            'settings': {
              ...presetList[index]['settings']! as Map<String, Object?>,
              ...body['settings'] as Map<String, dynamic>,
            },
        };
        presetList = [...presetList]..[index] = changed;
        onlyDefault(changed);
        return FakeResponse(200, changed);
      default:
        return FakeResponse(200, presetList[index]);
    }
  }

  static final RegExp _jobRoute = RegExp(
    '^(GET|POST) /organizations/[^/]+/jobs'
    r'(?:/([^/]+))?(/events|/cancel|/retry)?$',
  );

  /// The job history: recording a job and what happens to it, and reading
  /// it back.
  FakeResponse _answerJobs(
    RegExpMatch route,
    Map<String, dynamic> body,
    Map<String, List<String>> query,
  ) {
    final method = route.group(1)!;
    final jobId = route.group(2);
    final action = route.group(3);

    Map<String, Object?> record(
      Map<String, dynamic> create, {
      String? retryOf,
    }) {
      final settings = create['settings'] as Map<String, dynamic>?;
      final job = jobBody(
        id: create['id'] as String,
        type: create['type'] as String? ?? 'print',
        title: create['title'] as String?,
        printerId: create['printer_id'] as String,
        copies: settings?['copies'] as int? ?? 1,
        pageCount: create['page_count'] as int?,
        retryOf: retryOf,
      );
      jobList = [job, ...jobList];
      jobEvents[job['id']! as String] = [];
      return job;
    }

    Map<String, Object?> apply(String id, Map<String, dynamic> event) {
      final index = jobList.indexWhere((job) => job['id'] == id);
      jobEvents[id]!.add(event);
      final changed = {
        ...jobList[index],
        'status': event['status'],
        if (event['error_code'] != null) 'error_code': event['error_code'],
        if (event['error_message'] != null)
          'error_message': event['error_message'],
        if (event['connection_id'] != null)
          'connection_id': event['connection_id'],
      };
      jobList = [...jobList]..[index] = changed;
      return changed;
    }

    if (jobId == null) {
      if (method == 'POST') return FakeResponse(201, record(body));
      final wanted = query['status'] ?? const [];
      final matching = [
        for (final job in jobList)
          if (wanted.isEmpty || wanted.contains(job['status'])) job,
      ];
      // The cursor is how many jobs came before.
      final from = int.parse(query['cursor']?.single ?? '0');
      final to = from + jobPageSize;
      return FakeResponse(200, {
        'items': matching.skip(from).take(jobPageSize).toList(),
        'next_cursor': to < matching.length ? '$to' : null,
      });
    }
    if (jobId == 'batch') {
      return FakeResponse(200, {
        'results': [
          for (final item
              in (body['items'] as List<dynamic>).cast<Map<String, dynamic>>())
            {
              'idempotency_key': item['idempotency_key'],
              'outcome': 'created',
              'job': () {
                final job = record(item['job'] as Map<String, dynamic>);
                var latest = job;
                for (final event
                    in (item['events'] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>()) {
                  latest = apply(job['id']! as String, event);
                }
                return latest;
              }(),
              'error': null,
            },
        ],
      });
    }

    final index = jobList.indexWhere((job) => job['id'] == jobId);
    if (index < 0) return FakeResponse.problem(404, 'job.not_found');
    switch (action) {
      case '/events' when method == 'POST':
        return FakeResponse(200, apply(jobId, body));
      case '/events':
        return FakeResponse(200, [
          for (final (number, event) in jobEvents[jobId]!.indexed)
            {
              'id': 'event-$number',
              'status': event['status'],
              'connection_id': event['connection_id'],
              'connection_type': event['connection_id'] == null ? null : 'ipp',
              'error_code': event['error_code'],
              'error_message': event['error_message'],
              'reported_by_user_id': null,
              'detail': <String, Object?>{},
              'occurred_at': event['occurred_at'] ?? '2026-10-07T10:00:00Z',
              'created_at': '2026-10-07T10:00:00Z',
            },
        ]);
      case '/cancel':
        return FakeResponse(200, apply(jobId, {'status': 'cancelled'}));
      case '/retry':
        if (!const {'failed', 'cancelled'}.contains(jobList[index]['status'])) {
          return FakeResponse.problem(409, 'job.not_retryable');
        }
        return FakeResponse(
          201,
          record({...jobList[index], 'id': 'retry-of-$jobId'}, retryOf: jobId),
        );
      default:
        return FakeResponse(200, jobList[index]);
    }
  }

  static final RegExp _connectionRoute = RegExp(
    '^(GET|POST|PUT|PATCH|DELETE) /organizations/[^/]+/printers/([^/]+)'
    r'/connections(?:/([^/]+))?(/health)?$',
  );

  /// A printer's connections: listing, adding, ordering, changing, and
  /// removing them, and recording how each did.
  FakeResponse _answerConnections(
    RegExpMatch route,
    Map<String, dynamic> body,
  ) {
    final method = route.group(1)!;
    final printerId = route.group(2)!;
    final connectionId = route.group(3);
    final index = printerList.indexWhere((p) => p['id'] == printerId);
    if (index < 0) return FakeResponse.problem(404, 'printer.not_found');
    var connections = (printerList[index]['connections']! as List<dynamic>)
        .cast<Map<String, Object?>>();

    void save(List<Map<String, Object?>> changed) {
      connections = changed;
      printerList = [...printerList]
        ..[index] = {...printerList[index], 'connections': changed};
    }

    if (connectionId == null) {
      if (method == 'GET') return FakeResponse(200, connections);
      final configuration = body['configuration'] as Map<String, dynamic>;
      final created = connectionBody(
        type: body['type'] as String,
        host: configuration['host'] as String,
        port: configuration['port'] as int,
        path: configuration['path'] as String,
        priority: connections.length + 1,
        printerId: printerId,
        hasCredentials: body['credentials'] != null,
      );
      save([...connections, created]);
      return FakeResponse(201, created);
    }
    if (connectionId == 'priority') {
      final order = (body['connection_ids'] as List<dynamic>).cast<String>();
      if (order.toSet().length != connections.length ||
          !connections.every((c) => order.contains(c['id']))) {
        return FakeResponse.problem(422, 'connection.priority_mismatch');
      }
      save([
        for (final (position, id) in order.indexed)
          {
            ...connections.firstWhere((c) => c['id'] == id),
            'priority': position + 1,
          },
      ]);
      return FakeResponse(200, connections);
    }

    final at = connections.indexWhere((c) => c['id'] == connectionId);
    if (at < 0) return FakeResponse.problem(404, 'connection.not_found');
    if (method == 'DELETE') {
      save([...connections]..removeAt(at));
      return const FakeResponse(204);
    }
    final secrets = body['credentials'] as Map<String, dynamic>?;
    if (secrets != null) printerPasswords[printerId] = secrets;
    final changed = {
      ...connections[at],
      if (route.group(4) != null) 'health': body['health'],
      if (secrets != null) 'has_credentials': true,
    };
    save([...connections]..[at] = changed);
    return FakeResponse(200, changed);
  }

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

    if (route.group(4) == '/capabilities') {
      // What the phone found when it asked the printer again.
      final probed = printerBody(scans: body['scan'] != null);
      final recorded = {
        ...printerList[index],
        'capabilities': {
          ...probed['capabilities']! as Map<String, Object?>,
          'print': {
            ...(probed['capabilities']! as Map<String, Object?>)['print']!
                as Map<String, Object?>,
            'color':
                (body['print'] as Map<String, dynamic>?)?['color'] ?? false,
          },
        },
      };
      printerList = [...printerList]..[index] = recorded;
      return FakeResponse(200, recorded);
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

String _scannerStatus(String feeder) => [
  '<scan:ScannerStatus $_escl><pwg:State>Idle</pwg:State>',
  '<scan:AdfState>$feeder</scan:AdfState></scan:ScannerStatus>',
].join();

final String _scannerCapabilities = [
  '<scan:ScannerCapabilities $_escl>',
  '<pwg:MakeAndModel>Xerox VersaLink C7130</pwg:MakeAndModel>',
  '<scan:Platen><scan:PlatenInputCaps>',
  '<scan:MaxWidth>2550</scan:MaxWidth><scan:MaxHeight>3508</scan:MaxHeight>',
  '<scan:ColorMode>RGB24</scan:ColorMode>',
  '<pwg:DocumentFormat>application/pdf</pwg:DocumentFormat>',
  '<pwg:DocumentFormat>image/jpeg</pwg:DocumentFormat>',
  '<scan:XResolution>300</scan:XResolution>',
  '</scan:PlatenInputCaps></scan:Platen>',
  '<scan:Adf><scan:AdfSimplexInputCaps>',
  '<scan:ColorMode>RGB24</scan:ColorMode>',
  '</scan:AdfSimplexInputCaps></scan:Adf>',
  '</scan:ScannerCapabilities>',
].join();
