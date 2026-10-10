// Opens a link through a plugin, which only runs on a device.
// `FakeLinkOpener` stands in for it in tests.
// coverage:ignore-file
import 'package:printerhub/tools/code.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens links with the phone's browser, outside this app.
class UrlLauncherLinkOpener implements LinkOpener {
  const new();

  @override
  Future<bool> open(Uri link) async {
    try {
      return await launchUrl(link, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
