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
    // Flutter 侧有**控件级**聚焦节点（Tab 键盘导航 / 文本输入）——裸空格的
    // 键等价此时应放行给 Flutter（激活聚焦控件），详见 applyMenuItemState。
    var hasKeyboardFocus = false
    var sleepTimerMode = "off"  // "off" | "duration" | "endOfTrack" | "endOfQueue"
    var sleepTimerMinutes = 0  // duration 模式下当初设定的分钟数（勾选预设项用）
  }

  private var menuState = MenuState()
  private var menuChannel: FlutterMethodChannel?
  private var windowMenu: NSMenu?
  private var servicesMenu: NSMenu?
  private var keyMonitor: Any?

  // MARK: - 系统强调色（SystemAccentService ↔ System Settings 强调色）

  private var systemAccentChannel: FlutterMethodChannel?
  private var systemAccentObservers: [NSObjectProtocol] = []

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
      name: "com.jerryc.txvziwm/menu",
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
    menuState.hasKeyboardFocus = (args["hasKeyboardFocus"] as? Bool) ?? false
    menuState.sleepTimerMode = (args["sleepTimerMode"] as? String) ?? "off"
    menuState.sleepTimerMinutes = (args["sleepTimerMinutes"] as? NSNumber)?.intValue ?? 0
    // 主动刷新所有菜单项（使能/标题/勾选随播放态即时同步）。
    refreshAllMenuItems()
  }

  /// 把菜单动作转发给 Dart 侧 MenuService。
  private func sendMenuAction(_ action: String, value: Any? = nil) {
    guard let channel = menuChannel else { return }
    channel.invokeMethod("menuAction", arguments: ["action": action, "value": value ?? NSNull()])
  }

  // ⌘. 停止快捷键：由 installKeyShortcutMonitor 按 keyCode（47 = 句点键）+ ⌘ 捕获，
  // 并优先转交菜单系统 performKeyEquivalent 匹配（有菜单栏高亮反馈），失败才直接触发。

  // MARK: - 菜单动作（target = self → 转发 Dart）

  @objc private func playPauseTapped(_ sender: Any?) { sendMenuAction("playPause") }
  @objc private func previousTapped(_ sender: Any?) { sendMenuAction("previous") }
  @objc private func nextTapped(_ sender: Any?) { sendMenuAction("next") }
  @objc private func stopTapped(_ sender: Any?) { sendMenuAction("stop") }

  /// ⌘. 停止快捷键（local monitor 按 keyCode 捕获，任何输入法生效）。
  ///
  /// 背景（2026-08-31 多层探针实测）：Flutter macOS embedder 会在 `NSWindow.
  /// sendEvent` 之前把 `⌘.`（Command-Period）当"取消/停止"（等价 Escape）拦截，
  /// 菜单系统根本收不到 `⌘.` 组合键，所以 `keyEquivalent: "."` 匹配不上、菜单栏
  /// 无高亮。这里在**更早**的 local monitor 层按 keyCode（47 = 句点键）+ ⌘ 截住，
  /// 然后**优先转交 `NSApp.mainMenu?.performKeyEquivalent` 让菜单系统走标准匹配
  /// 路径**——实测成功：菜单系统能匹配 `keyEquivalent: "."`，AppKit 会自己高亮
  /// 菜单栏并触发「停止」action（借用菜单系统的原生反馈）；匹配失败才直接触发，
  /// 保证任何输入法下 ⌘. 都生效。
  ///
  /// ⚠️ 不要用 override NSWindow.performKeyEquivalent 兜底——会打断 AppKit 事件
  /// 链，导致 Esc 等键无限递归卡死。
  ///
  /// 修饰键必须**恰好**是 ⌘：`contains(.command)` 对 ⌘⇧. / ⌘⌥. 同样为真，会把
  /// 它们也当成停止（CapsLock / Fn / 小键盘标志不影响语义，先剔除）。
  private func installKeyShortcutMonitor() {
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self = self else { return event }
      // 只关心「纯 ⌘ + 句点键」（keyCode 47）。Flutter 引擎会在 sendEvent 之前把
      // ⌘. 当"取消"(Escape) 拦截，这里在更早的 local monitor 层截住它。
      let modifiers = event.modifierFlags
        .intersection(.deviceIndependentFlagsMask)
        .subtracting([.capsLock, .function, .numericPad])
      guard modifiers == .command, event.keyCode == 47 else { return event }
      // 先让菜单系统走标准匹配路径（performKeyEquivalent）：匹配成功时 AppKit 会
      // 自己高亮菜单栏并触发「停止」action（借用菜单系统的原生反馈）；失败再回退。
      if NSApp.mainMenu?.performKeyEquivalent(with: event) == true {
        return nil // 菜单系统已消费并触发 action
      }
      // 回退也要与菜单项使能一致：无曲目时「停止」不可点（否则会弹 HUD「已停止」）。
      if self.menuState.hasTrack {
        self.sendMenuAction("stop")
      }
      return nil // 消费事件，避免继续派发给 Flutter
    }
  }

  @objc private func volumeUpTapped(_ sender: Any?) { sendMenuAction("volumeUp") }
  @objc private func volumeDownTapped(_ sender: Any?) { sendMenuAction("volumeDown") }
  @objc private func singleRepeatTapped(_ sender: Any?) { sendMenuAction("toggleSingleRepeat") }
  @objc private func modeSequentialTapped(_ sender: Any?) { sendMenuAction("setPlayMode", value: "sequential") }
  @objc private func modeRepeatAllTapped(_ sender: Any?) { sendMenuAction("setPlayMode", value: "repeatAll") }
  @objc private func modeShuffleAllTapped(_ sender: Any?) { sendMenuAction("setPlayMode", value: "shuffleAll") }

  /// 睡眠定时（子菜单项共用）：预设分钟项用 `tag` 传分钟数，其余项用
  /// `representedObject` 传模式/取消字符串。
  @objc private func sleepTimerTapped(_ sender: Any?) {
    guard let menuItem = sender as? NSMenuItem else { return }
    if let value = menuItem.representedObject as? String {
      sendMenuAction("sleepTimer", value: value)
    } else {
      sendMenuAction("sleepTimer", value: menuItem.tag)
    }
  }
  @objc private func openSettingsTapped(_ sender: Any?) { sendMenuAction("openSettings") }
  @objc private func newPlaylistTapped(_ sender: Any?) { sendMenuAction("newPlaylist") }
  @objc private func importFolderTapped(_ sender: Any?) { sendMenuAction("importFolder") }
  @objc private func importPlaylistTapped(_ sender: Any?) { sendMenuAction("importPlaylist") }
  @objc private func exportPlaylistTapped(_ sender: Any?) { sendMenuAction("exportPlaylist") }

  /// 帮助 ›「关于本软件」：打开应用内的关于页（版本 / 开源许可 / 仓库链接）。
  /// 系统标准的「关于 %@」面板仍在 App 菜单里，两者并存。
  @objc private func openAboutTapped(_ sender: Any?) { sendMenuAction("openAbout") }

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
      // 播放/暂停标题随播放态切换；文本编辑 / 有控件持有键盘焦点时禁用。
      // 裸空格是「激活当前聚焦控件」的通用键（Flutter 侧 ActivateIntent，与
      // Enter 一致），菜单项被禁用后 AppKit 的键等价匹配会自动放行给 Flutter；
      // 没有聚焦控件时空格仍是播放/暂停（Apple Music 习惯）。
      menuItem.title = menuState.isPlaying
        ? NSLocalizedString("menu.pause", comment: "Pause")
        : NSLocalizedString("menu.play", comment: "Play")
      return menuState.hasTrack && !menuState.isTextEditing && !menuState.hasKeyboardFocus
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
    case #selector(sleepTimerTapped(_:)):
      // 「取消定时」只在有定时时可点；其余项要求有曲目（没歌时设定无意义）。
      if let value = menuItem.representedObject as? String {
        switch value {
        case "endOfTrack":
          menuItem.state = menuState.sleepTimerMode == "endOfTrack" ? .on : .off
          return menuState.hasTrack
        case "endOfQueue":
          menuItem.state = menuState.sleepTimerMode == "endOfQueue" ? .on : .off
          return menuState.hasTrack
        case "cancel":
          menuItem.state = .off
          return menuState.sleepTimerMode != "off"
        default:
          return false
        }
      }
      // 预设分钟项（tag = 分钟数）：与当初设定的时长一致时打勾。
      let isActive =
        menuState.sleepTimerMode == "duration"
        && menuState.sleepTimerMinutes == menuItem.tag
      menuItem.state = isActive ? .on : .off
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
      keyEquivalent: "." // ⌘. 停止（由 installKeyShortcutMonitor 拦截后优先走菜单系统匹配）
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

    menu.addItem(.separator())
    menu.addItem(sleepTimerSubmenuItem())

    item.submenu = menu
    return item
  }

  /// 睡眠定时子菜单：N 分钟 / 播完当前曲目 / 播完当前播放列表 / 取消定时。
  ///
  /// ⚠️ 预设分钟数必须与 Dart 侧 `SleepTimerButton.presets` 保持一致（两处各列一份，
  /// 改一处要记得改另一处）；Dart 按"当初设定的分钟数"回推勾选态。
  private func sleepTimerSubmenuItem() -> NSMenuItem {
    let title = NSLocalizedString("menu.sleepTimer", comment: "Sleep Timer")
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let menu = NSMenu(title: title)

    for minutes in [5, 10, 15, 30, 45, 60, 90] {
      let entry = NSMenuItem(
        title: String(
          format: NSLocalizedString("menu.sleepTimerMinutes", comment: "N Minutes"),
          minutes
        ),
        action: #selector(sleepTimerTapped(_:)),
        keyEquivalent: ""
      )
      entry.tag = minutes
      entry.target = self
      menu.addItem(entry)
    }

    menu.addItem(.separator())

    let endOfTrack = NSMenuItem(
      title: NSLocalizedString("menu.sleepTimerEndOfTrack", comment: "End of Track"),
      action: #selector(sleepTimerTapped(_:)),
      keyEquivalent: ""
    )
    endOfTrack.representedObject = "endOfTrack"
    endOfTrack.target = self
    menu.addItem(endOfTrack)

    let endOfQueue = NSMenuItem(
      title: NSLocalizedString("menu.sleepTimerEndOfQueue", comment: "End of Playlist"),
      action: #selector(sleepTimerTapped(_:)),
      keyEquivalent: ""
    )
    endOfQueue.representedObject = "endOfQueue"
    endOfQueue.target = self
    menu.addItem(endOfQueue)

    menu.addItem(.separator())

    let cancel = NSMenuItem(
      title: NSLocalizedString("menu.sleepTimerCancel", comment: "Cancel Timer"),
      action: #selector(sleepTimerTapped(_:)),
      keyEquivalent: ""
    )
    cancel.representedObject = "cancel"
    cancel.target = self
    menu.addItem(cancel)

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

    let about = NSMenuItem(
      title: NSLocalizedString("menu.aboutApp", comment: "About This App"),
      action: #selector(openAboutTapped(_:)),
      keyEquivalent: ""
    )
    about.target = self
    menu.addItem(about)

    item.submenu = menu
    return item
  }

  // MARK: - 系统强调色通道

  private func configureSystemAccentChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.jerryc.txvziwm/system_accent",
      binaryMessenger: binaryMessenger
    )
    systemAccentChannel = channel

    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getAccent":
        result(Self.currentSystemAccentRGB())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 系统强调色变化（系统设置 → 外观 → 强调色）时主动推给 Dart，实时跟随。
    let distributedCenter = DistributedNotificationCenter.default()
    systemAccentObservers.append(
      distributedCenter.addObserver(
        forName: NSNotification.Name("AppleColorPreferencesChangedNotification"),
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.pushSystemAccent()
      }
    )
    // 明暗外观切换时 controlAccentColor 解析出的强调色 shade 会变，一并重推。
    systemAccentObservers.append(
      distributedCenter.addObserver(
        forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.pushSystemAccent()
      }
    )
    // 兜底：应用回到前台时重读一次（覆盖 Multicolor 随壁纸派生等场景——
    // 该 SDK 无壁纸变化通知 API，改用前台重读）。
    systemAccentObservers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.pushSystemAccent()
      }
    )
  }

  private func pushSystemAccent() {
    guard let rgb = Self.currentSystemAccentRGB(),
          let channel = systemAccentChannel else { return }
    channel.invokeMethod("accentChanged", arguments: rgb)
  }

  /// 当前系统强调色 → [r, g, b]（0-255）。
  ///
  /// `NSColor.controlAccentColor` 是外观相关的动态色：在主线程读取时按应用
  /// 当前外观解析（明暗下强调色 shade 略有差异，属系统语义），转 sRGB 取分量。
  private static func currentSystemAccentRGB() -> [Int]? {
    guard let srgb = NSColor.controlAccentColor.usingColorSpace(.sRGB) else {
      return nil
    }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
    return [
      Int((r * 255).rounded()),
      Int((g * 255).rounded()),
      Int((b * 255).rounded()),
    ]
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // 不用 `as!`：窗口 / 根控制器类型变化时会在启动阶段直接崩，绕过 Flutter 侧
    // 的启动错误页。取不到就跳过原生通道注册（应用仍可作为普通播放器使用）。
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      NSLog("[0x4D] contentViewController is not a FlutterViewController; "
        + "menu/sandbox/system-accent channels not registered")
      return
    }

    // 程序化主菜单（文案见 en/zh-Hans.lproj/Localizable.strings）+ 菜单通道。
    configureMenuChannel(binaryMessenger: controller.engine.binaryMessenger)
    configureMainMenu()
    // ⌘. 停止快捷键：local monitor 拦截并优先转交菜单系统匹配（含菜单栏高亮）。
    installKeyShortcutMonitor()

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

    // 系统强调色通道：Dart 查询 + 原生在系统强调色/壁纸(Multicolor)变化时推送。
    configureSystemAccentChannel(binaryMessenger: controller.engine.binaryMessenger)

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
