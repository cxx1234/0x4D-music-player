import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // MARK: - 顶栏双击拦截（DetailTopBar 按钮区，防误触发窗口缩放）

  /// DetailTopBar 出现计数（>0 启用拦截；详情页叠加时累加，pop 后递减）。
  private var topBarGuardCount = 0

  /// DetailTopBar 右侧 actions 组宽度（AppKit points；0 = 无 actions，右区不拦）。
  private var topBarActionsWidth: CGFloat = 0

  // 与 Flutter layoutConfig / DetailTopBar 对齐的布局常量（AppKit points）。
  private let detailTopBarHeight: CGFloat = 52    // detailTopBarHeight
  private let detailTopBarLeftInset: CGFloat = 95  // detailTopBarLeftInset
  private let backButtonHitWidth: CGFloat = 40    // 实测返回键命中区 40×40
  private let detailTopBarRightInset: CGFloat = 12  // DetailTopBar 右 padding

  // MARK: - 窗口几何持久化（见 docs/Pitfalls.md B10）

  // 不走 AppKit 的 persistent UI：它只恢复"退出时仍可见"的窗口，且恢复结果会被
  // contentMinSize 静默钳制（关窗退出后尺寸丢失 / 偶尔变成最小尺寸两个症状）。
  private static let minContentSize = NSSize(width: 640, height: 520)
  private static let defaultContentSize = NSSize(width: 800, height: 600)
  private static let frameDefaultsKey = "mainWindowFrame"  // [x, y, w, h]
  private var pendingFrameSave: DispatchWorkItem?

  override func sendEvent(_ event: NSEvent) {
    // 标题栏双击缩放是系统级行为（AppKit 标题栏 hit-test 区域）。
    // 有 DetailTopBar 时，拦截「返回键」与「右侧 actions 组」内的第二次点击，
    // 避免快速点按钮被识别成双击缩放窗口；顶栏其余空白仍保留系统双击缩放。
    // 注意：缩放由第二次 down 或第二次 up 触发，需两者都拦。
    let isMouseClick = event.type == .leftMouseDown || event.type == .leftMouseUp
    if isMouseClick, event.clickCount >= 2 {
      let w = self.frame.width
      let x = event.locationInWindow.x
      let yFromTop = self.frame.height - event.locationInWindow.y
      if topBarGuardCount > 0, yFromTop <= detailTopBarHeight {
        let inBack = x >= detailTopBarLeftInset
          && x < detailTopBarLeftInset + backButtonHitWidth
        let rightEdge = w - detailTopBarRightInset
        let inActions = topBarActionsWidth > 0
          && x > rightEdge - topBarActionsWidth && x <= rightEdge
        if inBack || inActions { return }
      }
    }
    super.sendEvent(event)
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 最小窗口尺寸：宽 640 < 播放页双栏断点(760) → 窄模式仍可到达；
    // 单栏内容超高时由 Flutter 侧 SingleChildScrollView 兜底。
    self.contentMinSize = Self.minContentSize

    // 窗口几何由本类自己保存（见 restoreSavedFrame / observeFrameChanges），
    // 关掉 AppKit 的窗口状态恢复，避免两套机制抢同一个 frame。
    self.isRestorable = false

    // 隐藏标题栏 + unified 工具栏（macOS 11+）：
    // 红绿灯由 AppKit 原生垂直居中于工具栏行，从启动起位置即稳定，
    // 不再用 setFrameOrigin 与 AppKit 布局争夺。
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.styleMask.insert(.unifiedTitleAndToolbar)

    let toolbar = NSToolbar(identifier: "MainToolbar")
    toolbar.delegate = self
    toolbar.displayMode = .iconOnly
    toolbar.allowsUserCustomization = false
    toolbar.autosavesConfiguration = false
    toolbar.sizeMode = .regular
    self.toolbar = toolbar
    // 统一标题栏+工具栏（macOS 11+）：红绿灯原生垂直居中于工具栏行。
    self.toolbarStyle = .unified

    // 红绿灯绿钮：设为「最大化窗口」(zoom) 而非「全屏」。
    // FullScreenPrimary/Auxiliary 与 FullScreenNone 互斥；显式移除全屏能力后，
    // AppKit 自动把绿钮降级为缩放按钮（点击执行 performZoom → maximize）。
    self.collectionBehavior.remove([.fullScreenPrimary, .fullScreenAuxiliary])
    self.collectionBehavior.insert(.fullScreenNone)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 顶栏双击拦截：Dart 侧 DetailTopBar 上报出现计数与 actions 组宽度。
    let channel = FlutterMethodChannel(
      name: "com.jerryc.txvziwm/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setTopBarGuard":
        if let enabled = call.arguments as? Bool {
          let next = (self?.topBarGuardCount ?? 0) + (enabled ? 1 : -1)
          self?.topBarGuardCount = max(0, next)
        }
        result(nil)
      case "setActionsWidth":
        if let width = call.arguments as? Double {
          self?.topBarActionsWidth = CGFloat(width)
        }
        result(nil)
      case "showMainWindow":
        // 点击切歌通知时把已关闭的窗口唤回（App 关窗驻留后台，可能没有可见窗口）。
        self?.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        result(nil)
      default:
        result(nil)
      }
    }

    // 几何持久化：先挂监听（拖动 / 关窗 / 失焦 / 退出都会落盘），再套用上次的 frame。
    observeFrameChanges()
    restoreSavedFrame()

    super.awakeFromNib()
  }

  // MARK: - 窗口几何持久化

  private func observeFrameChanges() {
    let center = NotificationCenter.default
    // 用户拖动 / 缩放结束时的兜底（setFrame 覆盖在 setFrame 那一层已经拦了大部分）。
    for name in [NSWindow.didMoveNotification, NSWindow.didEndLiveResizeNotification] {
      center.addObserver(
        self, selector: #selector(scheduleFrameSave), name: name, object: self)
    }
    // 关窗（App 继续驻留后台）、切走、退出：立刻落盘，保证任何退出路径都记得。
    for name in [
      NSWindow.willCloseNotification,
      NSApplication.didResignActiveNotification,
      NSApplication.willTerminateNotification,
    ] {
      center.addObserver(
        self, selector: #selector(saveFrameNow), name: name, object: nil)
    }
  }

  /// 所有 frame 变化（用户拖动 / 程序化设置 / zoom）都经过这里，挂在这一层最稳。
  override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    super.setFrame(frameRect, display: flag)
    scheduleFrameSave()
  }

  private func restoreSavedFrame() {
    // 兼容数字与字符串：app 自己写的是 Double，手工 `defaults write -array` 写的是字符串。
    let saved = (UserDefaults.standard.array(forKey: Self.frameDefaultsKey) ?? []).compactMap {
      ($0 as? NSNumber)?.doubleValue ?? ($0 as? String).flatMap(Double.init)
    }
    guard saved.count == 4 else {
      resetToDefaultFrame()
      return
    }
    let savedFrame = NSRect(x: saved[0], y: saved[1], width: saved[2], height: saved[3])
    // 存档比最小窗口还小（旧版本遗留 / 畸形）→ 回落默认尺寸，
    // 而不是交给 AppKit 钳成 640×520（那正是要修的症状）。
    guard savedFrame.width >= Self.minContentSize.width,
          savedFrame.height >= Self.minContentSize.height,
          let screen = Self.screenWithLargestOverlap(of: savedFrame)
    else {
      resetToDefaultFrame()
      return
    }
    setFrame(Self.fitted(savedFrame, into: screen.visibleFrame), display: false)
  }

  private func resetToDefaultFrame() {
    setContentSize(Self.defaultContentSize)
    guard let visible = NSScreen.main?.visibleFrame else { return }
    let size = frame.size
    setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
  }

  @objc private func scheduleFrameSave() {
    pendingFrameSave?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.saveFrameNow() }
    pendingFrameSave = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
  }

  @objc private func saveFrameNow() {
    pendingFrameSave?.cancel()
    pendingFrameSave = nil
    guard isVisible, !isMiniaturized else { return }
    let current = frame
    guard current.width >= Self.minContentSize.width,
          current.height >= Self.minContentSize.height
    else { return }
    UserDefaults.standard.set(
      [current.origin.x, current.origin.y, current.width, current.height],
      forKey: Self.frameDefaultsKey)
  }

  /// 取与给定 rect 重叠面积最大的屏幕；完全在屏外则交给主屏兜底。
  private static func screenWithLargestOverlap(of rect: NSRect) -> NSScreen? {
    var best: NSScreen?
    var bestArea: CGFloat = 0
    for screen in NSScreen.screens {
      let overlap = screen.visibleFrame.intersection(rect).size
      let area = overlap.width * overlap.height
      if area > bestArea {
        bestArea = area
        best = screen
      }
    }
    return bestArea > 0 ? best : NSScreen.main
  }

  /// 把 rect 收进屏幕可见区域：先收到屏幕大小，再平移进边界（不改变用户意图的尺寸）。
  private static func fitted(_ rect: NSRect, into bounds: NSRect) -> NSRect {
    var result = rect
    result.size.width = min(result.width, bounds.width)
    result.size.height = min(result.height, bounds.height)
    result.origin.x = min(max(result.minX, bounds.minX), bounds.maxX - result.width)
    result.origin.y = min(max(result.minY, bounds.minY), bounds.maxY - result.height)
    return result
  }
}

/// 空 unified 工具栏的占位 item（避免空工具栏塌缩）。
private let toolbarSpacerID = NSToolbarItem.Identifier("trafficLightSpacer")

extension MainFlutterWindow: NSToolbarDelegate {
  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [toolbarSpacerID]
  }
  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [toolbarSpacerID]
  }
  func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
               willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    return item
  }
}
