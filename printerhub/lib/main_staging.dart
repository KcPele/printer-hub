import 'package:printerhub/app/app.dart';
import 'package:printerhub/bootstrap.dart';

Future<void> main() async {
  await bootstrap(
    AppConfig.production(),
    (dependencies) => App(
      preferencesRepository: dependencies.preferencesRepository,
      authRepository: dependencies.authRepository,
      organizationsRepository: dependencies.organizationsRepository,
      printersRepository: dependencies.printersRepository,
      jobsRepository: dependencies.jobsRepository,
      presetsRepository: dependencies.presetsRepository,
      finders: dependencies.finders,
      documents: dependencies.documents,
      scanSharer: dependencies.scanSharer,
      keptOrganizations: dependencies.keptOrganizations,
    ),
  );
}
