import 'dart:async';
import 'dart:developer';

import 'package:app_ui/app_ui.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:preferences_repository/preferences_repository.dart';

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

/// What every flavor needs before the first frame.
typedef AppDependencies = ({PreferencesRepository preferencesRepository});

Future<void> bootstrap(
  FutureOr<Widget> Function(AppDependencies dependencies) builder,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  Bloc.observer = const AppBlocObserver();

  // Volt's licensed font is registered when its files are in the build.
  await AppFonts.loadLicensed();

  // The chosen theme is read before the first frame, so the app never
  // flashes the wrong one.
  final preferencesRepository = await PreferencesRepository.open();

  runApp(await builder((preferencesRepository: preferencesRepository)));
}
