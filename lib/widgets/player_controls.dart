import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/services/playback_feedback_service.dart';
import '../core/services/player_service.dart';
import 'control_pulse.dart';

/// 播放控制按钮行：上一首 / 播放·暂停 / 下一首。
///
/// 循环/随机等播放模式按钮已移至播放队列功能栏。
///
/// - [compact]：B 两栏 / 迷你播放器用小号按钮。
/// - [alignment]：默认居中；B 两栏传 [MainAxisAlignment.start] 左对齐。
/// - [pulses]：外部操作（快捷键/媒体键）的脉冲源，让对应按钮也亮一下。
class PlayerControls extends StatelessWidget {
  final PlayerService player;
  final ThemeData theme;
  final bool compact;
  final MainAxisAlignment alignment;
  final ValueListenable<PlaybackPulse?>? pulses;

  const PlayerControls({
    super.key,
    required this.player,
    required this.theme,
    this.compact = false,
    this.alignment = MainAxisAlignment.center,
    this.pulses,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        // Previous（图标尺寸固定不随 compact 缩小——切歌按钮保持不变）
        ControlPulse(
          pulses: pulses,
          action: PlaybackAction.previous,
          builder: (context, pulsing) => _ControlButton(
            icon: Icons.skip_previous_rounded,
            isActive: pulsing,
            iconSize: 32,
            tooltip: '上一首',
            onPressed: player.previous,
          ),
        ),
        SizedBox(width: compact ? 6 : 8),

        // Play / Pause：脉冲时沿用激活态底色（图标本身已随播放态翻转）
        ControlPulse(
          pulses: pulses,
          action: PlaybackAction.playPause,
          builder: (context, pulsing) => IconButton(
            iconSize: compact ? 44 : 64,
            tooltip: player.isPlaying ? '暂停' : '播放',
            onPressed: player.togglePlay,
            style: pulsing
                ? IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer,
                  )
                : null,
            icon: Icon(
              player.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: pulsing
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.primary,
            ),
          ),
        ),
        SizedBox(width: compact ? 6 : 8),

        // Next（图标尺寸固定不随 compact 缩小——切歌按钮保持不变）
        ControlPulse(
          pulses: pulses,
          action: PlaybackAction.next,
          builder: (context, pulsing) => _ControlButton(
            icon: Icons.skip_next_rounded,
            isActive: pulsing,
            iconSize: 32,
            tooltip: '下一首',
            onPressed: player.next,
          ),
        ),
      ],
    );
  }
}

/// 控制行里的小图标按钮：激活态圆形底色 + 阴影；hover 不受影响。
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double iconSize;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    this.onPressed,
    this.tooltip,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      iconSize: iconSize,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        // 激活态：圆形底色 + 轻阴影；未激活：透明无阴影。
        // hover 涟漪是独立的 overlay，不受 elevation 影响。
        backgroundColor: isActive
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        foregroundColor: isActive ? theme.colorScheme.onPrimaryContainer : null,
        elevation: isActive ? 2 : 0,
      ),
      icon: Icon(icon),
    );
  }
}
