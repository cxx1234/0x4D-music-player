import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Keep running in the background after the window is closed so playback
    // continues and the system media keys / Now Playing stay controllable.
    return false
  }

  // 点击 Dock 图标时:若没有可见窗口,把已关闭的主窗口重新显示出来。
  // 窗口对象在关闭后仍存活(MainMenu.xib 的 releasedWhenClosed="NO",
  // MainFlutterWindow 持有 contentViewController → Flutter 引擎/Dart 状态都在内存中),
  // 因此重新显示不会丢失任何状态。
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      showMainWindow()
    }
    return true
  }

  /// 把主窗口重新带到前台。reopen 委托与 Dock 右键菜单共用。
  @objc private func showMainWindow() {
    mainFlutterWindow?.makeKeyAndOrderFront(nil)
    // 前台激活:NSRunningApplication.current.activate(options:) 自 macOS 10.6 起可用、
    // 至今未被弃用,兼容部署目标(11.0)与 macOS 14+ 对 NSApp.activate(ignoringOtherApps:) 的弃用变更。
    NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
  }

  // Dock 右键菜单:「Show Window」,窗口关闭后也能主动唤回主窗口。
  // 注意:Dock 菜单通过 NSApplicationDelegate 的 applicationDockMenu(_:) 提供,
  // NSDockTile 并没有公开的 menu 属性(编译期即可发现)。
  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let dockMenu = NSMenu()
    let showWindowItem = NSMenuItem(
      title: "Show Window",
      action: #selector(showMainWindow),
      keyEquivalent: ""
    )
    showWindowItem.target = self
    dockMenu.addItem(showWindowItem)
    return dockMenu
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.jerryc.txvziwm/sandbox",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
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
          // 检查是否真的获得了访问权限；失败时明确报错，而不是静默返回路径。
          guard url.startAccessingSecurityScopedResource() else {
            result(FlutterError(code: "ACCESS_FAILED", message: "Failed to start accessing the security-scoped resource", details: nil))
            return
          }
          result(url.path)
        } catch {
          result(FlutterError(code: "RESOLVE_FAILED", message: error.localizedDescription, details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Register the system media controls plugin (MPRemoteCommandCenter +
    // MPNowPlayingInfoCenter → Now Playing / Control Center / media keys).
    // On macOS, plugins are registered through the FlutterViewController's
    // registrar (FlutterAppDelegate does not expose `registrar(forPlugin:)`).
    MediaControlsPlugin.register(
      with: controller.registrar(forPlugin: "MediaControlsPlugin")
    )

    super.applicationDidFinishLaunching(notification)
  }
}
