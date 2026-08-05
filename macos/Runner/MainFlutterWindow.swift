import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// 顶部高度参数（由 Flutter 通过 MethodChannel「flutter_music/window」传入，
  /// 对应 lib/core/constants/layout.dart 的 layoutConfig.sidebarTopInset
  /// （左侧边栏顶部预留高度，macOS=56）。
  /// 红绿灯垂直居中于该区域，且 上 padding = 左 padding。
  private var topBarHeight: CGFloat = 56

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 最小窗口尺寸：宽 640 < 播放页双栏断点(760) → 窄模式仍可到达；
    // 单栏内容超高时由 Flutter 侧 SingleChildScrollView 兜底。
    self.contentMinSize = NSSize(width: 640, height: 520)

    // 隐藏标题栏：标题栏透明 + 隐藏标题文字 + 内容区扩展到整个窗口。
    // 红绿灯按钮由原生层（repositionTrafficLights）垂直居中于 Flutter 顶栏。
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 接收 Flutter 传入的顶部高度参数（红绿灯定位用）。
    let channel = FlutterMethodChannel(
      name: "flutter_music/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setTopBarHeight",
            let height = call.arguments as? Double else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.topBarHeight = CGFloat(height)
      self?.repositionTrafficLights()
      result(nil)
    }

    super.awakeFromNib()

    // 首帧后调整红绿灯位置（此时按钮已创建）。
    DispatchQueue.main.async { [weak self] in
      self?.repositionTrafficLights()
    }
    // 窗口布局变化（resize / 全屏进出 / 缩放因子变化）后维持位置。
    for name in [
      NSWindow.didResizeNotification,
      NSWindow.didEnterFullScreenNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didChangeBackingPropertiesNotification,
    ] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(repositionTrafficLights), name: name, object: self)
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  /// 红绿灯定位：垂直居中于顶部区域（topBarHeight），且 上 padding = 左 padding。
  ///
  /// 红绿灯位置完全由 Flutter 侧 layoutConfig.sidebarTopInset 决定：
  /// 后期通过调整该值即可保持红绿灯与左侧栏等元素的对齐（见 docs/UI-Rules.md）。
  @objc func repositionTrafficLights() {
    guard let close = standardWindowButton(.closeButton),
          let mini = standardWindowButton(.miniaturizeButton),
          let zoom = standardWindowButton(.zoomButton),
          let host = close.superview
    else { return }

    let buttonHeight = close.frame.height
    let hostHeight = host.frame.height
    // 垂直居中于 topBarHeight 区域：上 padding = (topBarHeight - 按钮高) / 2。
    let topPadding = (topBarHeight - buttonHeight) / 2
    // 左 padding = 上 padding（对称）。
    let left = topPadding
    // 按钮 frame 的 y（相对 host 底部）：中心距窗口顶 = topBarHeight / 2。
    let y = hostHeight - topBarHeight / 2 - buttonHeight / 2

    let spacing = mini.frame.minX - close.frame.maxX
    close.setFrameOrigin(NSPoint(x: left, y: y))
    mini.setFrameOrigin(NSPoint(x: close.frame.maxX + spacing, y: y))
    zoom.setFrameOrigin(NSPoint(x: mini.frame.maxX + spacing, y: y))
  }
}
