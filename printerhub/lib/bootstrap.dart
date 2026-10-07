import 'dart:async';
import 'dart:developer';

import 'package:api_client/api_client.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:local_store/local_store.dart';
import 'package:organizations_repository/organizations_repository.dart';
import 'package:preferences_repository/preferences_repository.dart';
import 'package:printer_protocols/printer_protocols.dart';
import 'package:printerhub/app/config/app_config.dart';
import 'package:printers_repository/printers_repository.dart';

class AppBlocObserver extends BlocObserver {
  const new();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    log('onChange(${bloc.runtimeType}, $change)');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    super.onError(bloc, error, stackTrace);
  }
}

/// What the app is built from, ready before the first frame.
typedef AppDependencies = ({
  PreferencesRepository preferencesRepository,
  AuthRepository authRepository,
  OrganizationsRepository organizationsRepository,
  PrintersRepository printersRepository,
  List<Organization>? keptOrganizations,
});

Future<void> bootstrap(
  AppConfig config,
  FutureOr<Widget> Function(AppDependencies dependencies) builder,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  Bloc.observer = const AppBlocObserver();

  // Volt's licensed font is registered when its files are in the build.
  await AppFonts.loadLicensed();

  // Everything below is read from the device, never the network, so the
  // first frame is the right one: the chosen theme, and Home for someone
  // who is already signed in.
  final preferencesRepository = await PreferencesRepository.open();
  const secureStore = KeystoreSecureStore();
  final client = PrinterHubClient(
    baseUrl: config.apiBaseUrl,
    tokenStore: const SecureTokenStore(secureStore),
  );
  final authRepository = AuthRepository(client: client, store: secureStore);
  final organizationsRepository = OrganizationsRepository(
    client: client,
    store: secureStore,
  );
  // Printers sign their own certificates. Each one is trusted the first
  // time it is seen and refused if it later changes.
  final printersRepository = PrintersRepository(
    client: client,
    probe: DeviceProbe(
      http: IoPrinterHttp(
        connectTimeout: const Duration(seconds: 3),
        certificateCheck: CertificateTrust().check,
      ),
    ),
    store: secureStore,
  );
  await authRepository.restore();

  runApp(
    await builder((
      preferencesRepository: preferencesRepository,
      authRepository: authRepository,
      organizationsRepository: organizationsRepository,
      printersRepository: printersRepository,
      keptOrganizations: await organizationsRepository.kept(),
    )),
  );
}
