import 'dart:async';

import 'package:flutter/widgets.dart';

/// HUD 消息的种类：同一种类连续更新只原地改文本（不重放入场动画），
/// 种类变化才做交叉淡入。
enum HudKind { volume, track, playback }

/// 一条浮动提示的内容（图标 + 文本）。
@immutable
class HudMessage {
  const HudMessage({
    required this.icon,
    required this.text,
    required this.kind,
  });

  final IconData icon;
  final String text;
  final HudKind kind;

  @override
  bool operator ==(Object other) =>
      other is HudMessage &&
      other.icon == icon &&
      other.text == text &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(icon, text, kind);
}

/// 底部浮动提示（HUD）的状态源：谁都可以 [show]，由 `HudOverlay` 渲染。
///
/// 与 SnackBar 的分工（**不要混用**）：
/// - SnackBar：需要阅读/确认的通知（播放错误、导入导出结果），出现频率低；
/// - HUD：操作回显（音量、切歌、播放/暂停），1 秒级自动消失，且**连续操作时
///   原地更新而不是排队** —— 按住 ⌘↑ 不该攒出十来个提示。
class HudService extends ChangeNotifier {
  /// 提示默认停留时长；连续 [show] 会重新计时。
  static const Duration defaultDuration = Duration(milliseconds: 1200);

  HudMessage? _message;
  Timer? _timer;

  /// 当前应显示的提示；null 表示不显示。
  HudMessage? get message => _message;

  /// 显示（或原地更新）一条提示，[duration] 之后自动消失。
  void show(HudMessage message, {Duration? duration}) {
    // 顺序要紧：先挂上新 Timer 再 notify —— 监听方（HudOverlay 在"不需要
    // HUD"的位置会立刻 dismiss）取消的必须是这条新计时器，不能留下野 Timer。
    _timer?.cancel();
    _message = message;
    _timer = Timer(duration ?? defaultDuration, dismiss);
    notifyListeners();
  }

  /// 立即隐藏（重复调用无副作用）。
  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
