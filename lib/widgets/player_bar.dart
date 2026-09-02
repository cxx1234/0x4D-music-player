import 'package:flutter/material.dart';

import '../core/services/player_service.dart';
import '../core/services/service_locator.dart';
import 'player_controls.dart';
import 'player_progress_bar.dart';

/// 全宽底部播放条：进度条 + 控制按钮 + 音量滑块（最右），不含播放信息。
///
/// 宽窄窗口共用；[compact] 传 true 时控制按钮用小号（窄窗口）。
class PlayerBar extends StatelessWidget {
  final PlayerService player;
  final ThemeData theme;
  final ValueChanged<Duration> onSeek;
  final bool compact;

  const PlayerBar({
    super.key,
    required this.player,
    required this.theme,
    required this.onSeek,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      // 与主界面底部栏一致：surfaceContainerLow 与页面背景区分。
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 进度条（全宽）──
            // 进度需随 positionStream（~200ms）刷新：这里局部订阅本 service，
            // 只让进度条子树随进度重建，避免父级整页连带重建。
            ListenableBuilder(
              listenable: player,
              builder: (context, _) => PlayerProgressBar(
                position: player.position,
                duration: player.duration,
                onSeek: onSeek,
                theme: theme,
              ),
            ),
            const SizedBox(height: 4),
            // ── 控制按钮（整条正中心）+ 音量滑块（最右）──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 左侧与音量块等宽的占位，让控制按钮严格居中于整条
                // （不被右侧音量区挤偏）。
                const SizedBox(width: _kVolumeBlockWidth),
                Expanded(
                  child: PlayerControls(
                    player: player,
                    theme: theme,
                    compact: compact,
                  ),
                ),
                SizedBox(
                  width: _kVolumeBlockWidth,
                  child: _VolumeSlider(player: player, theme: theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 音量块总宽（图标 20 + 间距 4 + 滑块 120）。左右各占一块使控制按钮居中。
const double _kVolumeBlockWidth = 144;

/// 音量滑块：显示当前音量并拖动调整（0.0~1.0，持久化到 settings）。
///
/// 拖动时在滑块上方显示百分比提示（字号与进度条时长一致）。
class _VolumeSlider extends StatefulWidget {
  final PlayerService player;
  final ThemeData theme;

  const _VolumeSlider({required this.player, required this.theme});

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  PlayerService get player => widget.player;
  ThemeData get theme => widget.theme;

  /// 拖动中的音量值（null = 未拖动，隐藏百分比提示）。
  double? _dragValue;

  /// 最近一次引擎音量（用于检测外部音量变化，如 macOS 菜单 ⌘↑/⌘↓）。
  late double _lastVolume;

  @override
  void initState() {
    super.initState();
    _lastVolume = player.volume;
    // 监听引擎音量变化：菜单/其他入口调音量时滑块即时同步。
    // 仅音量值实际变化才重建，播放进度 notify 不会触发（值未变）。
    player.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    player.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onPlayerChanged() {
    final v = player.volume;
    if (v == _lastVolume) return;
    _lastVolume = v;
    if (!mounted) return;
    // 拖动中 UI 已由 onChanged 的 setState 驱动，无需重复重建。
    if (_dragValue == null) setState(() {});
  }

  IconData _iconFor(double v) {
    if (v <= 0) return Icons.volume_off_rounded;
    if (v < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    // 音量只在用户拖动/启动恢复时变化，不随播放进度刷新，
    // 无需订阅整个 service（否则播放中每 ~200ms 重建滑块）。
    final volume = _dragValue ?? player.volume;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(volume),
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            SliderTheme(
              data: SliderThemeData(
                // 与进度条一致：小圆点 + 细轨道。
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: SizedBox(
                width: 120,
                child: Slider(
                  value: volume,
                  onChangeStart: (v) => setState(() => _dragValue = v),
                  onChanged: (v) {
                    setState(() => _dragValue = v);
                    // 拖动中只实时应用到引擎，不写盘（避免每格重写 settings.json）。
                    player.setVolume(v);
                  },
                  onChangeEnd: (v) {
                    setState(() => _dragValue = null);
                    // 拖动结束才落盘一次。
                    ServiceLocator.settings.setVolume(v);
                  },
                ),
              ),
            ),
          ],
        ),
        if (_dragValue != null)
          // 提示贴音量条上方（文本高 ~16 + 间距 ~3），水平居中。
          Positioned(
            top: -10,
            left: 0,
            right: -26,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  '${(_dragValue! * 100).round()}%',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
