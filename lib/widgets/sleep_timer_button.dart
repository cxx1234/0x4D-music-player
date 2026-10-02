import 'package:flutter/material.dart';

import '../core/services/sleep_timer_service.dart';
import 'menu_morph_route.dart';
import 'morph_menu.dart';

/// 按钮高度。同时是悬停高亮的圆角半径的一半（36 → r18，胶囊）。
const double _kSize = 36;

/// 按钮悬停/水波高亮形状。
const BorderRadius _kHoverShape = BorderRadius.all(Radius.circular(_kSize / 2));

// 菜单的行样式与尺寸约定不在这里：`morph_menu.dart` 里那份是睡眠定时与
// 播放列表卡片共用的（宽高必须提前算准，两边各写一份迟早会走样）。

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

  /// 菜单里的预设时长。
  ///
  /// ⚠️ 这里只有 5 档，比 `macos/Runner/AppDelegate.swift` 的原生子菜单（还有
  /// 5/10 分钟）少两档：这是一张高度固定的容器变换面板，最小窗口（520 高）里
  /// 7 档会让面板被屏幕钳制、内部滚起来。原生菜单没有高度限制，保留全档。
  static const List<Duration> presets = [
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
          // 两种模式下这里是「播完当前播放列表」这种长文案，而播放条只给这个槽位
          // 144px（去掉内边距剩 128）。给省略兜底，字号放大/字体更宽时也不会溢出。
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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

    // 面板的宽高都必须**提前算准**（终点矩形是算出来的，不能像弹层菜单那样
    // 先布局再定位）；尺寸约定与行样式都在 `morph_menu.dart` 里共用。
    final entries = _entries(state);
    final dividerAfter = _dividerAfter(entries);

    Navigator.of(context)
        .push<String>(
          MenuMorphRoute<String>(
            anchorRect: anchor,
            panelSize: Size(
              MorphMenuPanel.widthFor(context, entries),
              MorphMenuPanel.heightFor(entries, dividerAfter: dividerAfter),
            ),
            panelShape: const RoundedRectangleBorder(
              borderRadius: kMorphMenuRadius,
            ),
            // 起点用按钮的底色（面板从按钮里"长"出来，颜色也一起过渡）。
            anchorColor: theme.colorScheme.surfaceContainerHighest,
            builder: (context, close) => MorphMenuPanel(
              entries: entries,
              dividerAfter: dividerAfter,
              onSelected: close,
            ),
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

  /// 菜单条目（顺序固定：预设 → 两个模式 → 激活时的「取消定时」）。
  List<MorphMenuEntry<String>> _entries(SleepTimerState? state) => [
    for (final preset in presets)
      MorphMenuEntry('${preset.inMinutes} 分钟', '${preset.inMinutes}'),
    MorphMenuEntry.checkable(
      '播完当前曲目',
      _kEndOfTrack,
      checked: state?.mode == SleepTimerMode.endOfTrack,
    ),
    MorphMenuEntry.checkable(
      '播完当前播放列表',
      _kEndOfQueue,
      checked: state?.mode == SleepTimerMode.endOfQueue,
    ),
    if (state != null)
      // 倒计时模式下把剩余时间写在取消项里：菜单里的选项无法"勾选"一个正在
      // 递减的值，这是唯一能显示进度的位置（淡出期间显示「正在淡出…」，
      // 提示用户此刻取消还来得及）。
      MorphMenuEntry('取消定时（${sleepTimerLabel(state)}）', _kCancel),
  ];

  /// 分隔线位置：预设与模式之间一条，激活时模式与「取消定时」之间再来一条。
  Set<int> _dividerAfter(List<MorphMenuEntry<String>> entries) => {
    presets.length - 1,
    if (entries.length > presets.length + 2) entries.length - 2,
  };
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
