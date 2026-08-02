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

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
