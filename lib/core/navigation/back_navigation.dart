import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 桌面端「返回」的输入判定与分发。
///
/// 把鼠标侧键变成「返回」的路径取决于 remap 工具怎么配，常见的有：
///
/// 1. **原样透传鼠标后退按钮**（button 4）→ [PointerDownEvent.buttons] 带
///    [kBackMouseButton]。Flutter 的 macOS embedder 会转发它（实测
///    `buttons=0x08`），所以用一层根 [Listener] 就能收到。
/// 2. **合成 HID 浏览器后退键** → [LogicalKeyboardKey.browserBack]。
/// 3. **合成快捷键 ⌘[**（Safari / Finder 的默认，也是多数键盘类工具的默认）。
///
/// 还有一种（`SensibleSideButtons` 的做法）是**合成滑动手势**
/// （`NSEventTypeGesture` + swipe 子类型）：Flutter 引擎只转发键盘 / 鼠标 / 滚轮，
/// 手势事件根本到不了 Dart。**本项目不支持**这类工具 —— 要么关掉它（原始按钮那条
/// 路即可用），要么让它改发 ⌘[（机制、探针与取舍见 `docs/Pitfalls.md` B9）。
///
/// ⚠️ 不认 ⌘← / ⌘→：macOS 菜单里它们是「上一首 / 下一首」。
///
/// 前进一律忽略：Navigator 没有前进历史（pop 掉的 route 实例不能复用），做「前进」
/// 要自己维护页面工厂 + 状态快照，不值当。
class BackNavigationHandler {
  BackNavigationHandler({required this.onBack});

  final VoidCallback onBack;

  /// 键盘兜底：注册给 `FocusManager.addLateKeyEventHandler`。
  ///
  /// 用 late handler 而不是根级 `Shortcuts`，理由同 Esc 那个（见
  /// `utils/keyboard_focus.dart`）：只有对话框 / 弹层菜单 / 文本框都没处理该键时
  /// 才轮到它，不会抢输入控件。
  KeyEventResult handleKey(KeyEvent event) {
    if (!isBackKeyEvent(event)) return KeyEventResult.ignored;
    onBack();
    return KeyEventResult.handled;
  }

  /// 指针侧键。**只挂 down**：up 事件里的 `buttons` 已经是松开后的状态。
  void handlePointerDown(PointerDownEvent event) {
    if (!isBackPointerEvent(event)) return;
    onBack();
  }
}

/// 该按键事件是否代表「返回」。
///
/// 只认按下：up / repeat 不算 —— 长按不该连续弹路由。
bool isBackKeyEvent(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  if (event.logicalKey == LogicalKeyboardKey.browserBack) return true;
  return event.logicalKey == LogicalKeyboardKey.bracketLeft &&
      HardwareKeyboard.instance.isMetaPressed;
}

/// 该指针事件是否按下了鼠标「后退」键（button 4，`buttons` 的 0x08 位）。
bool isBackPointerEvent(PointerEvent event) =>
    event.buttons & kBackMouseButton != 0;

/// 弹掉最上层路由；已经在主界面（无可弹路由）时什么都不做。
///
/// 对话框 / 右键菜单 / BottomSheet 都挂在同一个 Navigator 上，所以它们也是一层
/// —— 会先被关掉，符合「一层一层退」。回到 Shell 后不切 tab、不退出应用。
void popTopRoute(NavigatorState? navigator) {
  if (navigator == null || !navigator.canPop()) return;
  navigator.maybePop();
}
