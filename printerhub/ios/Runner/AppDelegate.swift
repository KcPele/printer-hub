import Flutter
import UIKit
import Vision
import VisionKit

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
    PageCamera.shared.attach(to: engineBridge.applicationRegistrar.messenger())
  }
}

/// Opens the phone's document camera for the Flutter side, over the
/// `printerhub/page_camera` channel. It finds each page, straightens it,
/// and hands back a JPEG file a page.
final class PageCamera: NSObject, VNDocumentCameraViewControllerDelegate {
  static let shared = PageCamera()

  private var channel: FlutterMethodChannel?
  private var answer: FlutterResult?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "printerhub/page_camera",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "available":
        result(VNDocumentCameraViewController.isSupported)
      case "capture":
        self?.open(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  private func open(_ result: @escaping FlutterResult) {
    guard VNDocumentCameraViewController.isSupported, answer == nil,
      let screen = Self.topScreen()
    else {
      result(FlutterError(code: "page_camera.unavailable", message: nil, details: nil))
      return
    }
    answer = result
    let camera = VNDocumentCameraViewController()
    camera.delegate = self
    screen.present(camera, animated: true)
  }

  /// The screen that is showing, to put the camera over.
  private static func topScreen() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var screen = window?.rootViewController
    while let above = screen?.presentedViewController {
      screen = above
    }
    return screen
  }

  private func finish(_ camera: VNDocumentCameraViewController, with value: Any?) {
    let answer = self.answer
    self.answer = nil
    camera.dismiss(animated: true) { answer?(value) }
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFinishWith scan: VNDocumentCameraScan
  ) {
    let folder = FileManager.default.temporaryDirectory
    let name = UUID().uuidString
    var paths: [String] = []
    for page in 0..<scan.pageCount {
      let file = folder.appendingPathComponent("camera-\(name)-\(page + 1).jpg")
      guard let picture = scan.imageOfPage(at: page).jpegData(compressionQuality: 0.85),
        (try? picture.write(to: file)) != nil
      else {
        finish(
          controller,
          with: FlutterError(code: "page_camera.storage", message: nil, details: nil)
        )
        return
      }
      paths.append(file.path)
    }
    finish(controller, with: paths)
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    finish(controller, with: [String]())
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFailWithError error: Error
  ) {
    finish(
      controller,
      with: FlutterError(
        code: "page_camera.failed",
        message: error.localizedDescription,
        details: nil
      )
    )
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
