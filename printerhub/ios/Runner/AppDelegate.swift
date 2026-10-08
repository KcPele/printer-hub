import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    IncomingFiles.shared.attach(to: engineBridge.applicationRegistrar.messenger())
    ScanText.shared.attach(to: engineBridge.applicationRegistrar.messenger())
  }
}

/// Reads the words in scanned pages for the Flutter side, over the
/// `printerhub/scan_text` channel, with Vision. The pages never leave the
/// phone.
final class ScanText {
  static let shared = ScanText()

  private var channel: FlutterMethodChannel?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "printerhub/scan_text",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, call.method == "read",
        let paths = call.arguments as? [String]
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      // Reading takes a moment a page: off the main thread.
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let pages = try paths.map { try self.read(URL(fileURLWithPath: $0)) }
          let text = pages.filter { !$0.isEmpty }.joined(separator: "\n\n")
          DispatchQueue.main.async { result(text) }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "scan_text.unreadable",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }
    }
    self.channel = channel
  }

  /// The lines of one page, top to bottom.
  private func read(_ picture: URL) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(url: picture, options: [:]).perform([request])
    return (request.results ?? [])
      .compactMap { $0.topCandidates(1).first?.string }
      .joined(separator: "\n")
  }
}
