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
    self.contentMinSize = NSSize(width: 640, height: 520)

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
    // setTopBarHeight 为兼容旧调用（仅保持通道平衡）。
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
      default:
        result(nil)
      }
    }

    super.awakeFromNib()
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
