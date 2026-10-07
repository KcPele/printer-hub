import 'package:printerhub/app/app.dart';
import 'package:printerhub/bootstrap.dart';

Future<void> main() async {
  await bootstrap(
    (dependencies) =>
        App(preferencesRepository: dependencies.preferencesRepository),
  );
}
