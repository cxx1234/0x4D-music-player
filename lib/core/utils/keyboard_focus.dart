import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 键盘导航（Tab）焦点的判定与退出口。
///
/// 背景（2026-09-23 实测）：Flutter 里 Tab 能进入键盘导航，但**没有退出口** ——
/// Esc 的默认映射（`DismissIntent`）在普通页面路由上被禁用（页面
/// `barrierDismissible` 为 false），鼠标点击既不清焦点也不切回 touch 高亮模式
/// （3.47 的 `_HighlightModeManager.handlePointerEvent` 只处理 touch/stylus），
/// 于是焦点环会一直留在屏幕上，空格又一直激活那个「看不见的」聚焦按钮。

/// 是否存在**真实的**聚焦控件（= 键盘导航已生效）。
///
/// 路由自身的 [FocusScopeNode] 持有焦点属于常态（[ModalRoute] 的 FocusScope 带
/// `autofocus`，启动后 [FocusManager.primaryFocus] 就是它），不能算键盘导航 ——
/// 否则全局空格键（播放 / 暂停）在任何时刻都会被判定为「应让给 Flutter」。
bool get hasKeyboardFocus {
  final focus = FocusManager.instance.primaryFocus;
  return focus != null && focus is! FocusScopeNode;
}

/// 取消当前键盘焦点，返回是否真的做了操作（没有聚焦控件时为 false）。
///
/// 取消后焦点回到最近的 [FocusScopeNode]，Tab 可再次进入键盘导航。
bool clearKeyboardFocus() {
  if (!hasKeyboardFocus) return false;
  FocusManager.instance.primaryFocus!.unfocus();
  return true;
}

/// Esc 取消键盘焦点（注册给 [FocusManager.addLateKeyEventHandler]）。
///
/// 用 **late** handler 而不是根级 `Shortcuts`：late handler 只在「没有任何控件 /
/// 路由处理该键」时才运行，因此对话框（Esc 关闭）、弹层菜单（`MenuAnchor`）、
/// 文本框（`ToolbarSearchField` 自带 `Focus.onKeyEvent`）的 Esc 全部优先，不会被
/// 劫持。⚠️ 不要改成根级 `Shortcuts(escape: ...)`：那会抢在 `WidgetsApp` 默认映射
/// 之前，使对话框的 Esc 失效（实测对话框关不掉）。
KeyEventResult handleKeyboardFocusKeyEvent(KeyEvent event) {
  if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) {
    return KeyEventResult.ignored;
  }
  return clearKeyboardFocus() ? KeyEventResult.handled : KeyEventResult.ignored;
}
