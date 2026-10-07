/// What differs between the development, staging, and production builds.
class AppConfig {
  const new({required this.apiBaseUrl});

  /// A backend on the developer's machine. Override with
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:8000` on an Android
  /// emulator, where `localhost` is the emulator itself.
  factory development() {
    return AppConfig(
      apiBaseUrl: Uri.parse(
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://localhost:8000',
        ),
      ),
    );
  }

  /// The live API. Staging uses it too until a staging backend exists.
  factory production() {
    return AppConfig(
      apiBaseUrl: Uri.parse('https://printerhub-backend.kcpele.com'),
    );
  }

  final Uri apiBaseUrl;
}
