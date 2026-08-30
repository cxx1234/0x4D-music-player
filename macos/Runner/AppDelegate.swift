import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // MARK: - 菜单动态状态（Dart 侧 MenuService 推送，validateMenuItem 读取）

  /// 决定菜单项使能/标题/勾选的当前状态快照。
  private struct MenuState {
    var hasTrack = false
    var isPlaying = false
    var isShuffled = false
    var repeatMode = "off"  // "off" | "one" | "all"
    var isTextEditing = false
  }

  private var menuState = MenuState()
  private var menuChannel: FlutterMethodChannel?
  private var windowMenu: NSMenu?
  private var servicesMenu: NSMenu?

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

  // MARK: - 菜单通道

  private func configureMenuChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "flutter_music/menu",
      binaryMessenger: binaryMessenger
    )
    menuChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "updateMenuState":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID", message: "updateMenuState requires a map", details: nil))
          return
        }
        self.applyMenuState(args)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func applyMenuState(_ args: [String: Any]) {
    menuState.hasTrack = (args["hasTrack"] as? Bool) ?? false
    menuState.isPlaying = (args["isPlaying"] as? Bool) ?? false
    menuState.isShuffled = (args["isShuffled"] as? Bool) ?? false
    menuState.repeatMode = (args["repeatMode"] as? String) ?? "off"
    menuState.isTextEditing = (args["isTextEditing"] as? Bool) ?? false
    // 主动刷新所有菜单项（使能/标题/勾选随播放态即时同步）。
    refreshAllMenuItems()
  }

  /// 把菜单动作转发给 Dart 侧 MenuService。
  private func sendMenuAction(_ action: String, value: Any? = nil) {
    guard let channel = menuChannel else { return }
    channel.invokeMethod("menuAction", arguments: ["action": action, "value": value ?? NSNull()])
  }

  // MARK: - 菜单动作（target = self → 转发 Dart）

  @objc private func playPauseTapped(_ sender: Any?) { sendMenuAction("playPause") }
  @objc private func previousTapped(_ sender: Any?) { sendMenuAction("previous") }
  @objc private func nextTapped(_ sender: Any?) { sendMenuAction("next") }
  @objc private func stopTapped(_ sender: Any?) { sendMenuAction("stop") }
  @objc private func volumeUpTapped(_ sender: Any?) { sendMenuAction("volumeUp") }
  @objc private func volumeDownTapped(_ sender: Any?) { sendMenuAction("volumeDown") }
  @objc private func singleRepeatTapped(_ sender: Any?) { sendMenuAction("toggleSingleRepeat") }
  @objc private func modeSequentialTapped(_ sender: Any?) { sendMenuAction("setPlayMode", value: "sequential") }
  @objc private func modeRepeatAllTapped(_ sender: Any?) { sendMenuAction("setPlayMode", value: "repeatAll") }
  @objc private func modeShuffleAllTapped(_ sender: Any?) { sendMenuAction("setPlayMode", value: "shuffleAll") }
  @objc private func openSettingsTapped(_ sender: Any?) { sendMenuAction("openSettings") }
  @objc private func newPlaylistTapped(_ sender: Any?) { sendMenuAction("newPlaylist") }
  @objc private func importFolderTapped(_ sender: Any?) { sendMenuAction("importFolder") }
  @objc private func importPlaylistTapped(_ sender: Any?) { sendMenuAction("importPlaylist") }
  @objc private func exportPlaylistTapped(_ sender: Any?) { sendMenuAction("exportPlaylist") }

  // MARK: - 菜单校验（使能 / 标题 / 勾选）

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    // 仅校验 target 为自身的播放/设置项；标准系统项交给 responder chain 自动使能。
    guard menuItem.target === self else { return true }
    return applyMenuItemState(menuItem)
  }

  /// 按 menuState 刷新单个菜单项的状态（标题/勾选/使能），返回是否启用。
  @discardableResult
  private func applyMenuItemState(_ menuItem: NSMenuItem) -> Bool {
    switch menuItem.action {
    case #selector(playPauseTapped(_:)):
      // 播放/暂停标题随播放态切换；文本编辑时禁用（空格快捷键让给文本框）。
      menuItem.title = menuState.isPlaying
        ? NSLocalizedString("menu.pause", comment: "Pause")
        : NSLocalizedString("menu.play", comment: "Play")
      return menuState.hasTrack && !menuState.isTextEditing
    case #selector(previousTapped(_:)), #selector(nextTapped(_:)):
      // 文本编辑时禁用 ⌘←/⌘→（让给文本框的“行首/行尾”）。
      return menuState.hasTrack && !menuState.isTextEditing
    case #selector(stopTapped(_:)):
      return menuState.hasTrack
    case #selector(singleRepeatTapped(_:)):
      menuItem.state = menuState.repeatMode == "one" ? .on : .off
      return menuState.hasTrack
    case #selector(modeSequentialTapped(_:)):
      menuItem.state =
        (menuState.repeatMode == "off" && !menuState.isShuffled) ? .on : .off
      return menuState.hasTrack
    case #selector(modeRepeatAllTapped(_:)):
      menuItem.state =
        (menuState.repeatMode == "all" && !menuState.isShuffled) ? .on : .off
      return menuState.hasTrack
    case #selector(modeShuffleAllTapped(_:)):
      menuItem.state =
        (menuState.repeatMode == "all" && menuState.isShuffled) ? .on : .off
      return menuState.hasTrack
    default:
      return true
    }
  }

  /// 主动刷新主菜单全部项：播放态变化时调用，保证勾选/标题/使能即时同步，
  /// 不依赖菜单被打开或 NSMenu.update 的行为。
  private func refreshAllMenuItems() {
    guard let mainMenu = NSApp.mainMenu else { return }
    for top in mainMenu.items {
      refreshMenuItemsRecursively(top)
    }
  }

  private func refreshMenuItemsRecursively(_ item: NSMenuItem) {
    if item.target === self {
      item.isEnabled = applyMenuItemState(item)
    }
    if let submenu = item.submenu {
      for child in submenu.items {
        refreshMenuItemsRecursively(child)
      }
    }
  }

  // MARK: - 主菜单构建

  private func configureMainMenu() {
    let mainMenu = NSMenu(title: "Main Menu")
    mainMenu.addItem(appMenuItem())
    mainMenu.addItem(fileMenuItem())
    mainMenu.addItem(editMenuItem())
    mainMenu.addItem(windowMenuItem())
    mainMenu.addItem(playbackMenuItem())
    mainMenu.addItem(helpMenuItem())
    NSApp.mainMenu = mainMenu
    NSApp.windowsMenu = windowMenu
    if let servicesMenu = servicesMenu {
      NSApp.servicesMenu = servicesMenu
    }
  }

  private func appMenuItem() -> NSMenuItem {
    let appName = ProcessInfo.processInfo.processName
    let item = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
    let menu = NSMenu(title: appName)

    let about = NSMenuItem(
      title: String(format: NSLocalizedString("menu.about", comment: "About"), appName),
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
      keyEquivalent: ""
    )
    menu.addItem(about)

    menu.addItem(.separator())

    let preferences = NSMenuItem(
      title: NSLocalizedString("menu.preferences", comment: "Preferences"),
      action: #selector(openSettingsTapped(_:)),
      keyEquivalent: ","
    )
    preferences.target = self
    menu.addItem(preferences)

    menu.addItem(.separator())

    let servicesMenu = NSMenu(title: NSLocalizedString("menu.services", comment: "Services"))
    let servicesItem = NSMenuItem(
      title: NSLocalizedString("menu.services", comment: "Services"),
      action: nil,
      keyEquivalent: ""
    )
    servicesItem.submenu = servicesMenu
    self.servicesMenu = servicesMenu
    menu.addItem(servicesItem)

    menu.addItem(.separator())

    let hide = NSMenuItem(
      title: String(format: NSLocalizedString("menu.hide", comment: "Hide"), appName),
      action: #selector(NSApplication.hide(_:)),
      keyEquivalent: "h"
    )
    menu.addItem(hide)

    let hideOthers = NSMenuItem(
      title: NSLocalizedString("menu.hideOthers", comment: "Hide Others"),
      action: #selector(NSApplication.hideOtherApplications(_:)),
      keyEquivalent: "h"
    )
    hideOthers.keyEquivalentModifierMask = [.command, .option]
    menu.addItem(hideOthers)

    let showAll = NSMenuItem(
      title: NSLocalizedString("menu.showAll", comment: "Show All"),
      action: #selector(NSApplication.unhideAllApplications(_:)),
      keyEquivalent: ""
    )
    menu.addItem(showAll)

    menu.addItem(.separator())

    let quit = NSMenuItem(
      title: String(format: NSLocalizedString("menu.quit", comment: "Quit"), appName),
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    menu.addItem(quit)

    item.submenu = menu
    return item
  }

  private func playbackMenuItem() -> NSMenuItem {
    let item = NSMenuItem(
      title: NSLocalizedString("menu.playback", comment: "Playback"),
      action: nil,
      keyEquivalent: ""
    )
    let menu = NSMenu(title: NSLocalizedString("menu.playback", comment: "Playback"))

    let previous = NSMenuItem(
      title: NSLocalizedString("menu.previous", comment: "Previous"),
      action: #selector(previousTapped(_:)),
      keyEquivalent: "\u{F702}"
    )
    previous.keyEquivalentModifierMask = [.command]
    previous.target = self
    menu.addItem(previous)

    let playPause = NSMenuItem(
      title: NSLocalizedString("menu.play", comment: "Play"),
      action: #selector(playPauseTapped(_:)),
      keyEquivalent: " "
    )
    // 裸空格（Apple Music 风格），非 ⌘空格：NSMenuItem 键等价默认带 ⌘，需显式清空。
    playPause.keyEquivalentModifierMask = []
    playPause.target = self
    menu.addItem(playPause)

    let next = NSMenuItem(
      title: NSLocalizedString("menu.next", comment: "Next"),
      action: #selector(nextTapped(_:)),
      keyEquivalent: "\u{F703}"
    )
    next.keyEquivalentModifierMask = [.command]
    next.target = self
    menu.addItem(next)

    let stop = NSMenuItem(
      title: NSLocalizedString("menu.stop", comment: "Stop"),
      action: #selector(stopTapped(_:)),
      keyEquivalent: "."
    )
    stop.target = self
    menu.addItem(stop)

    menu.addItem(.separator())

    let volumeUp = NSMenuItem(
      title: NSLocalizedString("menu.volumeUp", comment: "Increase Volume"),
      action: #selector(volumeUpTapped(_:)),
      keyEquivalent: "\u{F700}"
    )
    volumeUp.keyEquivalentModifierMask = [.command]
    volumeUp.target = self
    menu.addItem(volumeUp)

    let volumeDown = NSMenuItem(
      title: NSLocalizedString("menu.volumeDown", comment: "Decrease Volume"),
      action: #selector(volumeDownTapped(_:)),
      keyEquivalent: "\u{F701}"
    )
    volumeDown.keyEquivalentModifierMask = [.command]
    volumeDown.target = self
    menu.addItem(volumeDown)

    menu.addItem(.separator())

    let singleRepeat = NSMenuItem(
      title: NSLocalizedString("menu.singleRepeat", comment: "Repeat One"),
      action: #selector(singleRepeatTapped(_:)),
      keyEquivalent: ""
    )
    singleRepeat.target = self
    menu.addItem(singleRepeat)

    // 播放模式子菜单：顺序 / 列表循环 / 随机循环 三选一勾选。
    let playModeItem = NSMenuItem(
      title: NSLocalizedString("menu.playMode", comment: "Play Mode"),
      action: nil,
      keyEquivalent: ""
    )
    let playModeMenu = NSMenu(title: NSLocalizedString("menu.playMode", comment: "Play Mode"))
    let sequential = NSMenuItem(
      title: NSLocalizedString("menu.modeSequential", comment: "Sequential"),
      action: #selector(modeSequentialTapped(_:)),
      keyEquivalent: ""
    )
    sequential.target = self
    playModeMenu.addItem(sequential)
    let repeatAll = NSMenuItem(
      title: NSLocalizedString("menu.modeRepeatAll", comment: "Repeat All"),
      action: #selector(modeRepeatAllTapped(_:)),
      keyEquivalent: ""
    )
    repeatAll.target = self
    playModeMenu.addItem(repeatAll)
    let shuffleAll = NSMenuItem(
      title: NSLocalizedString("menu.modeShuffleAll", comment: "Shuffle"),
      action: #selector(modeShuffleAllTapped(_:)),
      keyEquivalent: ""
    )
    shuffleAll.target = self
    playModeMenu.addItem(shuffleAll)
    playModeItem.submenu = playModeMenu
    menu.addItem(playModeItem)

    item.submenu = menu
    return item
  }

  private func fileMenuItem() -> NSMenuItem {
    let item = NSMenuItem(
      title: NSLocalizedString("menu.file", comment: "File"),
      action: nil,
      keyEquivalent: ""
    )
    let menu = NSMenu(title: NSLocalizedString("menu.file", comment: "File"))

    // 导入文件夹置顶。
    let importFolder = NSMenuItem(
      title: NSLocalizedString("menu.importFolder", comment: "Import Folder"),
      action: #selector(importFolderTapped(_:)),
      keyEquivalent: "o"
    )
    importFolder.target = self
    menu.addItem(importFolder)

    menu.addItem(.separator())

    // 播放列表操作同一类：新建 / 导入 / 导出。
    let newPlaylist = NSMenuItem(
      title: NSLocalizedString("menu.newPlaylist", comment: "New Playlist"),
      action: #selector(newPlaylistTapped(_:)),
      keyEquivalent: "n"
    )
    newPlaylist.target = self
    menu.addItem(newPlaylist)

    let importPlaylist = NSMenuItem(
      title: NSLocalizedString("menu.importPlaylist", comment: "Import Playlist"),
      action: #selector(importPlaylistTapped(_:)),
      keyEquivalent: "i"
    )
    importPlaylist.target = self
    menu.addItem(importPlaylist)

    let exportPlaylist = NSMenuItem(
      title: NSLocalizedString("menu.exportPlaylist", comment: "Export Playlist"),
      action: #selector(exportPlaylistTapped(_:)),
      keyEquivalent: ""
    )
    exportPlaylist.target = self
    menu.addItem(exportPlaylist)

    menu.addItem(.separator())

    // 关闭窗口：File 菜单惯例（⌘W），后台继续播放，Dock 唤回可恢复。
    let close = NSMenuItem(
      title: NSLocalizedString("menu.closeWindow", comment: "Close Window"),
      action: #selector(NSWindow.performClose(_:)),
      keyEquivalent: "w"
    )
    menu.addItem(close)

    item.submenu = menu
    return item
  }

  private func editMenuItem() -> NSMenuItem {
    let item = NSMenuItem(
      title: NSLocalizedString("menu.edit", comment: "Edit"),
      action: nil,
      keyEquivalent: ""
    )
    let menu = NSMenu(title: NSLocalizedString("menu.edit", comment: "Edit"))

    // 标准编辑命令走 responder chain（nil target）：Flutter 文本框聚焦时由
    // embedder 处理剪切/复制/粘贴；未聚焦时自动禁用。
    menu.addItem(
      withTitle: NSLocalizedString("menu.undo", comment: "Undo"),
      action: NSSelectorFromString("undo:"),
      keyEquivalent: "z"
    )
    menu.addItem(
      withTitle: NSLocalizedString("menu.redo", comment: "Redo"),
      action: NSSelectorFromString("redo:"),
      keyEquivalent: "Z"
    )
    menu.addItem(.separator())
    menu.addItem(
      withTitle: NSLocalizedString("menu.cut", comment: "Cut"),
      action: #selector(NSText.cut(_:)),
      keyEquivalent: "x"
    )
    menu.addItem(
      withTitle: NSLocalizedString("menu.copy", comment: "Copy"),
      action: #selector(NSText.copy(_:)),
      keyEquivalent: "c"
    )
    menu.addItem(
      withTitle: NSLocalizedString("menu.paste", comment: "Paste"),
      action: #selector(NSText.paste(_:)),
      keyEquivalent: "v"
    )
    menu.addItem(
      withTitle: NSLocalizedString("menu.delete", comment: "Delete"),
      action: #selector(NSText.delete(_:)),
      keyEquivalent: ""
    )
    menu.addItem(.separator())
    menu.addItem(
      withTitle: NSLocalizedString("menu.selectAll", comment: "Select All"),
      action: #selector(NSText.selectAll(_:)),
      keyEquivalent: "a"
    )

    item.submenu = menu
    return item
  }

  private func windowMenuItem() -> NSMenuItem {
    let title = NSLocalizedString("menu.window", comment: "Window")
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let menu = NSMenu(title: title)

    let minimize = NSMenuItem(
      title: NSLocalizedString("menu.minimize", comment: "Minimize"),
      action: #selector(NSWindow.performMiniaturize(_:)),
      keyEquivalent: "m"
    )
    menu.addItem(minimize)
    let zoom = NSMenuItem(
      title: NSLocalizedString("menu.zoom", comment: "Zoom"),
      action: #selector(NSWindow.performZoom(_:)),
      keyEquivalent: ""
    )
    menu.addItem(zoom)
    menu.addItem(.separator())
    let front = NSMenuItem(
      title: NSLocalizedString("menu.bringAllToFront", comment: "Bring All to Front"),
      action: #selector(NSApplication.arrangeInFront(_:)),
      keyEquivalent: ""
    )
    menu.addItem(front)

    item.submenu = menu
    windowMenu = menu
    return item
  }

  private func helpMenuItem() -> NSMenuItem {
    let title = NSLocalizedString("menu.help", comment: "Help")
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let menu = NSMenu(title: title)
    item.submenu = menu
    return item
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController

    // 程序化主菜单（文案见 en/zh-Hans.lproj/Localizable.strings）+ 菜单通道。
    configureMenuChannel(binaryMessenger: controller.engine.binaryMessenger)
    configureMainMenu()

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
