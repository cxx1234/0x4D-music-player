import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
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

    // 兼容旧调用：Flutter 启动仍会发 setTopBarHeight，这里仅保持通道平衡。
    let channel = FlutterMethodChannel(
      name: "flutter_music/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { _, result in
      result(nil)
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
