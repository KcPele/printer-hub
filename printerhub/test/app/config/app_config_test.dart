import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/app/app.dart';

void main() {
  group('AppConfig', () {
    test('development talks to a backend on this machine', () {
      expect(
        AppConfig.development().apiBaseUrl,
        Uri.parse('http://localhost:8000'),
      );
    });

    test('production talks to the live API over HTTPS', () {
      final url = AppConfig.production().apiBaseUrl;

      expect(url.scheme, 'https');
      expect(url.host, 'printerhub-backend.kcpele.com');
    });
  });
}
