import 'package:flutter/material.dart';

import '../core/services/hud_service.dart';

/// 底部居中的浮动提示（HUD）。
///
/// 挂在根 Overlay 的**第二条 entry** 上：比 Scaffold（连同其上的 SnackBar）更晚
/// 绘制，天然浮在最上层；距窗口底部 [kBottomInset]，把「底栏 + SnackBar」那一条
/// 让出来，两者同时出现也不重叠。
class HudOverlay extends StatefulWidget {
  const HudOverlay({super.key, required this.hud, this.enabled = true});

  /// 距窗口底部的留白：底栏 64（`NowPlayingBar` 的高度）+ SnackBar 单行 48
  /// （默认 fixed 行为，贴在底栏正上方）+ 间隙 12。
  ///
  /// ⚠️ 必须整条让开 SnackBar，否则提示会被它盖住。SnackBar 文案折成两行时
  /// 仍有轻微重叠，属可接受的极端情况。
  static const double kBottomInset = 124;

  final HudService hud;

  /// false = 当前位置不需要 HUD（正在播放页已有音量滑块、信息卡与控制按钮）。
  /// 期间到达的消息**直接丢弃**，避免离开该页时延迟弹出来。
  final bool enabled;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  static const Duration _kSwitchDuration = Duration(milliseconds: 160);

  @override
  void initState() {
    super.initState();
    widget.hud.addListener(_onHudChanged);
  }

  @override
  void didUpdateWidget(HudOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hud != widget.hud) {
      oldWidget.hud.removeListener(_onHudChanged);
      widget.hud.addListener(_onHudChanged);
    }
    if (!widget.enabled && widget.hud.message != null) widget.hud.dismiss();
  }

  @override
  void dispose() {
    widget.hud.removeListener(_onHudChanged);
    super.dispose();
  }

  /// 在不需要 HUD 的位置收到消息就地丢弃：`dismiss` 把 message 置空后还会
  /// 再回调一次，那次会立刻返回，不会死循环。
  void _onHudChanged() {
    if (!widget.enabled) widget.hud.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: widget.hud,
        builder: (context, _) {
          final message = widget.enabled ? widget.hud.message : null;
          // AnimatedSwitcher 用 kind 作 key：同一种类只原地改文本（按住 ⌘↑
          // 连发音量不会重放动画），种类变化才交叉淡入；外面套 AnimatedSize
          // 让文本变宽/变窄也平滑。
          return AnimatedSize(
            duration: _kSwitchDuration,
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: _kSwitchDuration,
              child: message == null
                  ? const SizedBox(width: 0, height: 0)
                  : _HudPill(
                      key: ValueKey<HudKind>(message.kind),
                      message: message,
                      theme: theme,
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// 提示气泡本体：深色圆角胶囊 + 图标 + 文本（iOS 音量 HUD 观感）。
class _HudPill extends StatelessWidget {
  const _HudPill({super.key, required this.message, required this.theme});

  final HudMessage message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final background = theme.colorScheme.inverseSurface;
    final foreground = theme.colorScheme.onInverseSurface;
    // 纯视觉回显，读屏念出来只会打断正在听的内容。
    return ExcludeSemantics(
      child: Material(
        color: background.withValues(alpha: 0.94),
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(message.icon, size: 18, color: foreground),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  message.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
