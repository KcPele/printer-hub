import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // A file another app opened in PrinterHub arrives here: as the app
  // starts, or while it is running.

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    takeFiles(from: connectionOptions.urlContexts)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let others = takeFiles(from: URLContexts)
    if !others.isEmpty {
      super.scene(scene, openURLContexts: others)
    }
  }

  /// Hands the files among [contexts] to the app, and returns the rest.
  @discardableResult
  private func takeFiles(from contexts: Set<UIOpenURLContext>) -> Set<UIOpenURLContext> {
    var others = Set<UIOpenURLContext>()
    for context in contexts {
      if context.url.isFileURL {
        IncomingFiles.shared.received(context.url)
      } else {
        others.insert(context)
      }
    }
    return others
  }
}

/// Passes files that were opened in PrinterHub to the Flutter side, over
/// the `printerhub/incoming_files` channel.
///
/// A file can arrive before Flutter is listening, when it is what started
/// the app. Those wait here until Flutter asks with `listen`.
final class IncomingFiles {
  static let shared = IncomingFiles()

  private var channel: FlutterMethodChannel?
  private var waiting: [String] = []
  private var listening = false

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "printerhub/incoming_files",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, call.method == "listen" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.listening = true
      result(self.waiting)
      self.waiting = []
    }
    self.channel = channel
    clearOldCopies()
  }

  /// iOS keeps the files it was handed in an Inbox folder of the app's:
  /// under Documents on older versions, under the temporary folder on
  /// newer ones. A copy from more than a day ago has been printed or
  /// forgotten, and goes.
  private func clearOldCopies() {
    let files = FileManager.default
    var folders = [
      files.temporaryDirectory.appendingPathComponent(
        "\(Bundle.main.bundleIdentifier ?? "")-Inbox"
      )
    ]
    if let documents = files.urls(for: .documentDirectory, in: .userDomainMask).first {
      folders.append(documents.appendingPathComponent("Inbox"))
    }
    let dayAgo = Date().addingTimeInterval(-24 * 60 * 60)
    for folder in folders {
      let copies =
        (try? files.contentsOfDirectory(
          at: folder,
          includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
      for copy in copies {
        let changed = try? copy.resourceValues(forKeys: [.contentModificationDateKey])
          .contentModificationDate
        if let changed = changed, changed < dayAgo {
          try? files.removeItem(at: copy)
        }
      }
    }
  }

  /// iOS has already made the app its own copy of the file.
  func received(_ url: URL) {
    if listening {
      channel?.invokeMethod("opened", arguments: url.path)
    } else {
      waiting.append(url.path)
    }
  }
}
