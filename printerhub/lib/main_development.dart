import 'package:printerhub/app/app.dart';
import 'package:printerhub/bootstrap.dart';

Future<void> main() async {
  await bootstrap(
    AppConfig.development(),
    (dependencies) => App(
      preferencesRepository: dependencies.preferencesRepository,
      authRepository: dependencies.authRepository,
      organizationsRepository: dependencies.organizationsRepository,
      keptOrganizations: dependencies.keptOrganizations,
    ),
  );
}
