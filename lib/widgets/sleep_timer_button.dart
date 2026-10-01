import 'package:flutter/material.dart';

import '../core/services/sleep_timer_service.dart';
import 'menu_morph_route.dart';

/// 按钮高度。同时是悬停高亮的圆角半径的一半（36 → r18，胶囊）。
const double _kSize = 36;

/// 按钮悬停/水波高亮形状。
const BorderRadius _kHoverShape = BorderRadius.all(Radius.circular(_kSize / 2));

/// 菜单面板的宽度与圆角，与全局 `PopupMenuThemeData` 的观感保持一致。
const double _kMenuWidth = 228;
const BorderRadius _kMenuShape = BorderRadius.all(Radius.circular(12));

/// 条目高度、分隔线高度、面板上下内边距。
///
/// 容器变换要**事先知道面板的准确高度**（终点矩形是算出来的，不能像弹层菜单
/// 那样先布局再定位），所以条目用固定行高，而不是 `MenuItemButton` 的最小高度。
const double _kRowHeight = 48;
const double _kDividerHeight = 8;
const double _kPanelPaddingV = 8;

/// 条目左右内边距（高亮边缘 → 文字）。
const double _kItemPaddingX = 20;

/// 播放条左侧的睡眠定时入口：计时器图标（+ 剩余时间），点击弹预设菜单。
///
/// 菜单用**容器变换**弹出（[MenuMorphRoute]）：面板从按钮这个矩形连续长出来，
/// 而不是在某处淡入/滑入。换掉 `PopupMenuButton` 的原因：它每帧都用当帧尺寸重算
/// 位置（`_PopupMenuRouteLayout` + `_fitInsideScreen`），菜单比按钮下方空间高时
/// 会被"底边钉住"、整张菜单从窗口下沿滑上来 —— 而播放条就在窗口最底部，必然触发
/// 这条分支，看着不像"从按钮展开"。
///
/// 菜单项、文案、回调与原来的弹出菜单一致。
///
/// 只有 [SleepTimerService] 一个依赖，菜单文案/时间格式都是本文件里的顶层纯函数，
/// 便于测试。
class SleepTimerButton extends StatelessWidget {
  const SleepTimerButton({
    super.key,
    required this.timer,
    required this.theme,
    this.compact = false,
  });

  final SleepTimerService timer;
  final ThemeData theme;

  /// 窄窗口：只显示图标，不显示剩余时间（留给音量块与控制按钮）。
  final bool compact;

  /// 菜单里的预设时长（⚠️ 与 `macos/Runner/AppDelegate.swift` 里那份保持一致）。
  static const List<Duration> presets = [
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(minutes: 60),
    Duration(minutes: 90),
  ];

  /// 菜单项的值：模式用固定字符串，预设用分钟数字符串。
  static const String _kEndOfTrack = 'endOfTrack';
  static const String _kEndOfQueue = 'endOfQueue';
  static const String _kCancel = 'cancel';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SleepTimerState?>(
      valueListenable: timer.state,
      builder: (context, state, _) {
        final active = state != null;
        // 激活时用主题色标出来：播放条上唯一能看出"定时开着"的地方。
        final color = active
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
        return Tooltip(
          message: state == null ? '睡眠定时' : '睡眠定时 · ${sleepTimerLabel(state)}',
          child: InkWell(
            onTap: () => _openMenu(context, state),
            borderRadius: _kHoverShape,
            child: SizedBox(
              height: _kSize,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _label(state, color),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 按钮显示区：图标 + 文案（图标态 36×36，带文案时是胶囊）。
  Widget _label(SleepTimerState? state, Color color) {
    final label = state == null
        ? '睡眠定时'
        : (state.fading ? '淡出中' : sleepTimerLabel(state));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          state == null ? Icons.timer_outlined : Icons.timer,
          size: 20,
          color: color,
        ),
        if (!compact) ...[
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
      ],
    );
  }

  /// 弹出"从按钮长出来"的菜单。
  void _openMenu(BuildContext context, SleepTimerState? state) {
    final box = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    // 锚点要换算到 overlay 坐标（路由就插在它里面）。
    final anchor =
        overlayBox.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;

    // 面板高度必须提前算准（见 `_kRowHeight` 的注释）：7 个预设 + 2 个模式
    // （+ 激活时的"取消定时"），分隔线是激活时 2 条、否则 1 条。
    final rows = presets.length + 2 + (state != null ? 1 : 0);
    final dividers = state != null ? 2 : 1;
    final height =
        rows * _kRowHeight + dividers * _kDividerHeight + 2 * _kPanelPaddingV;

    Navigator.of(context)
        .push<String>(
          MenuMorphRoute<String>(
            anchorRect: anchor,
            panelSize: Size(_kMenuWidth, height),
            panelShape: RoundedRectangleBorder(borderRadius: _kMenuShape),
            // 起点用按钮的底色（面板从按钮里"长"出来，颜色也一起过渡）。
            anchorColor: theme.colorScheme.surfaceContainerHighest,
            builder: (context, close) => _menuContent(context, close, state),
          ),
        )
        .then((value) {
          if (value != null) _onSelected(value);
        });
  }

  void _onSelected(String value) {
    if (value == _kCancel) {
      timer.cancel();
      return;
    }
    if (value == _kEndOfTrack) {
      timer.startForEndOfTrack();
      return;
    }
    if (value == _kEndOfQueue) {
      timer.startForEndOfQueue();
      return;
    }
    final minutes = int.tryParse(value);
    if (minutes != null) timer.startForDuration(Duration(minutes: minutes));
  }

  /// 菜单内容。行高固定，总高与 `_openMenu` 里算出来的一致；矮窗口下面板会被
  /// 屏幕高度钳制，那时靠这里的滚动消化。
  Widget _menuContent(
    BuildContext context,
    void Function([String? result]) close,
    SleepTimerState? state,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: _kPanelPaddingV),
          for (final preset in presets)
            _row('${preset.inMinutes} 分钟', () => close('${preset.inMinutes}')),
          const Divider(height: _kDividerHeight),
          _row(
            '播完当前曲目',
            () => close(_kEndOfTrack),
            checked: state?.mode == SleepTimerMode.endOfTrack,
          ),
          _row(
            '播完当前播放列表',
            () => close(_kEndOfQueue),
            checked: state?.mode == SleepTimerMode.endOfQueue,
          ),
          if (state != null) ...[
            const Divider(height: _kDividerHeight),
            // 倒计时模式下把剩余时间写在取消项里：菜单里的选项无法"勾选"一个
            // 正在递减的值，这是唯一能显示进度的位置（淡出期间显示「正在淡出…」，
            // 提示用户此刻取消还来得及）。
            _row('取消定时（${sleepTimerLabel(state)}）', () => close(_kCancel)),
          ],
          const SizedBox(height: _kPanelPaddingV),
        ],
      ),
    );
  }

  /// 一行菜单项。勾选框用透明图标占位，避免选中时行内文字左右跳动。
  Widget _row(String label, VoidCallback onTap, {bool checked = false}) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _kRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kItemPaddingX),
          child: Row(
            children: [
              Icon(
                Icons.check,
                size: 16,
                color: checked ? theme.colorScheme.primary : Colors.transparent,
              ),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// 睡眠定时状态的可读文案（菜单/tooltip 用）。
String sleepTimerLabel(SleepTimerState state) => switch (state.mode) {
  SleepTimerMode.duration =>
    state.fading
        ? '正在淡出…'
        : formatSleepTimerRemaining(state.remaining ?? Duration.zero),
  SleepTimerMode.endOfTrack => '播完当前曲目',
  SleepTimerMode.endOfQueue => '播完当前播放列表',
};

/// 把剩余时长格式化成 `M:SS`（满 1 小时为 `H:MM:SS`）。
String formatSleepTimerRemaining(Duration remaining) {
  final total = remaining.isNegative ? Duration.zero : remaining;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  return '$minutes:$ss';
}
