import 'package:flutter/material.dart';

import '../core/services/sleep_timer_service.dart';

/// 播放条左侧的睡眠定时入口：计时器图标（+ 剩余时间），点击弹预设菜单。
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

  /// 按钮高度；同时是悬停高亮的圆角半径的一半（36 → r18）。
  static const double _kSize = 36;

  /// 悬停/水波高亮形状：图标态是 36×36 的正圆，显示剩余时间时变成胶囊
  /// （与 AppBar 上的 `_AppBarTab` 同款观感）。
  /// 不传这个圆角的话，child 模式的 `PopupMenuButton` 用的是裸 `InkWell`，
  /// 高亮会被裁成方块。
  static const BorderRadius _kHoverShape = BorderRadius.all(
    Radius.circular(_kSize / 2),
  );

  final SleepTimerService timer;
  final ThemeData theme;

  /// 窄窗口：只显示图标，不显示剩余时间（留给音量块与控制按钮）。
  final bool compact;

  /// 菜单里的预设时长。
  static const List<Duration> presets = [
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(minutes: 60),
    Duration(minutes: 90),
  ];

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
        final remaining = state?.remaining;
        final tooltip = state == null
            ? '睡眠定时'
            : '睡眠定时 · ${sleepTimerLabel(state)}';
        return PopupMenuButton<String>(
          tooltip: tooltip,
          onSelected: _onSelected,
          itemBuilder: (context) => _buildItems(state),
          borderRadius: _kHoverShape,
          // child 模式：命中区 = 内容尺寸（下面的 SizedBox 定死高度）。
          child: SizedBox(
            height: _kSize,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? Icons.timer : Icons.timer_outlined,
                    size: 20,
                    color: color,
                  ),
                  if (active && !compact && remaining != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      formatSleepTimerRemaining(remaining),
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSelected(String value) {
    if (value == 'cancel') {
      timer.cancel();
      return;
    }
    if (value == 'endOfTrack') {
      timer.startForEndOfTrack();
      return;
    }
    if (value == 'endOfQueue') {
      timer.startForEndOfQueue();
      return;
    }
    final minutes = int.tryParse(value);
    if (minutes != null) timer.startForDuration(Duration(minutes: minutes));
  }

  List<PopupMenuEntry<String>> _buildItems(SleepTimerState? state) {
    final active = state != null;
    return [
      for (final preset in presets)
        PopupMenuItem<String>(
          value: '${preset.inMinutes}',
          child: Text('${preset.inMinutes} 分钟'),
        ),
      const PopupMenuDivider(),
      CheckedPopupMenuItem<String>(
        value: 'endOfTrack',
        checked: state?.mode == SleepTimerMode.endOfTrack,
        child: const Text('播完当前曲目'),
      ),
      CheckedPopupMenuItem<String>(
        value: 'endOfQueue',
        checked: state?.mode == SleepTimerMode.endOfQueue,
        child: const Text('播完当前播放列表'),
      ),
      if (active) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'cancel',
          // 倒计时模式下把剩余时间写在取消项里：菜单里的选项无法"勾选"一个
          // 正在递减的值，这是唯一能显示进度的位置。
          child: Text(
            state.remaining != null
                ? '取消定时（${formatSleepTimerRemaining(state.remaining!)}）'
                : '取消定时（${sleepTimerLabel(state)}）',
          ),
        ),
      ],
    ];
  }
}

/// 睡眠定时状态的可读文案（菜单/tooltip 用）。
String sleepTimerLabel(SleepTimerState state) => switch (state.mode) {
  SleepTimerMode.duration => formatSleepTimerRemaining(
    state.remaining ?? Duration.zero,
  ),
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
