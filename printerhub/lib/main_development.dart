import 'package:printerhub/app/app.dart';
import 'package:printerhub/bootstrap.dart';

Future<void> main() async {
  await bootstrap(
    AppConfig.development(),
    (dependencies) => App(
      preferencesRepository: dependencies.preferencesRepository,
      authRepository: dependencies.authRepository,
      organizationsRepository: dependencies.organizationsRepository,
      printersRepository: dependencies.printersRepository,
      jobsRepository: dependencies.jobsRepository,
      finders: dependencies.finders,
      documents: dependencies.documents,
      keptOrganizations: dependencies.keptOrganizations,
    ),
  );
}
