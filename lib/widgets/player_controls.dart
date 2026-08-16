import 'package:flutter/material.dart';

import '../core/services/player_service.dart';

/// 播放控制按钮行：循环 / 上一首 / 播放·暂停 / 下一首 / 随机。
///
/// - [compact]：B 两栏 / 迷你播放器用小号按钮。
/// - [alignment]：默认居中；B 两栏传 [MainAxisAlignment.start] 左对齐。
class PlayerControls extends StatelessWidget {
  final PlayerService player;
  final ThemeData theme;
  final bool compact;
  final MainAxisAlignment alignment;

  const PlayerControls({
    super.key,
    required this.player,
    required this.theme,
    this.compact = false,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        // Repeat mode
        _ControlButton(
          icon: _repeatIcon(player.repeatMode),
          isActive: player.repeatMode != PlayerRepeatMode.off,
          iconSize: compact ? 20 : 24,
          tooltip: '循环模式',
          onPressed: player.cycleRepeatMode,
        ),
        SizedBox(width: compact ? 6 : 8),

        // Previous（图标尺寸固定不随 compact 缩小——切歌按钮保持不变）
        _ControlButton(
          icon: Icons.skip_previous_rounded,
          isActive: false,
          iconSize: 32,
          tooltip: '上一首',
          onPressed: player.previous,
        ),
        SizedBox(width: compact ? 6 : 8),

        // Play / Pause
        IconButton(
          iconSize: compact ? 44 : 64,
          tooltip: player.isPlaying ? '暂停' : '播放',
          onPressed: player.togglePlay,
          icon: Icon(
            player.isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(width: compact ? 6 : 8),

        // Next（图标尺寸固定不随 compact 缩小——切歌按钮保持不变）
        _ControlButton(
          icon: Icons.skip_next_rounded,
          isActive: false,
          iconSize: 32,
          tooltip: '下一首',
          onPressed: player.next,
        ),
        SizedBox(width: compact ? 6 : 8),

        // Shuffle
        _ControlButton(
          icon: Icons.shuffle_rounded,
          isActive: player.isShuffled,
          iconSize: compact ? 20 : 24,
          tooltip: '随机播放',
          onPressed: player.toggleShuffle,
        ),
      ],
    );
  }

  IconData _repeatIcon(PlayerRepeatMode mode) {
    switch (mode) {
      case PlayerRepeatMode.off:
        return Icons.repeat_rounded;
      case PlayerRepeatMode.one:
        return Icons.repeat_one_rounded;
      case PlayerRepeatMode.all:
        return Icons.repeat_rounded;
    }
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
