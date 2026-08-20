import 'package:flutter/material.dart';

/// 播放进度条（纯展示组件）。
///
/// 位置 / 时长 / 跳转回调由外部传入，不依赖播放器 ViewModel，
/// 与 `PlayerControls` 一样放在公共 widgets/ 层（widgets/ 不能反向依赖 features/）。
class PlayerProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final ThemeData theme;

  const PlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.theme,
  });

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds > 0
        ? duration
        : const Duration(seconds: 1);

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: position.inMilliseconds.toDouble().clamp(
              0,
              max.inMilliseconds.toDouble(),
            ),
            max: max.inMilliseconds.toDouble(),
            onChanged: (v) => onSeek(Duration(milliseconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(position), style: theme.textTheme.bodySmall),
              Text(_format(duration), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
