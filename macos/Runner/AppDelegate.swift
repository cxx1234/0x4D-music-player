import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.jerryc.flutter_music/sandbox",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "createBookmark":
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "INVALID", message: "Path required", details: nil))
          return
        }
        let url = URL(fileURLWithPath: path)
        do {
          let bookmarkData = try url.bookmarkData(
            options: .securityScopeAllowOnlyReadAccess,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          result(bookmarkData.base64EncodedString())
        } catch {
          result(FlutterError(code: "BOOKMARK_FAILED", message: error.localizedDescription, details: nil))
        }

      case "resolveBookmark":
        guard let base64 = call.arguments as? String,
              let data = Data(base64Encoded: base64) else {
          result(FlutterError(code: "INVALID", message: "Bookmark data required", details: nil))
          return
        }
        var isStale = false
        do {
          let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
          )
          if isStale {
            result(FlutterError(code: "STALE", message: "Bookmark is stale, please re-add the folder", details: nil))
            return
          }
          _ = url.startAccessingSecurityScopedResource()
          result(url.path)
        } catch {
          result(FlutterError(code: "RESOLVE_FAILED", message: error.localizedDescription, details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.applicationDidFinishLaunching(notification)
  }
}
