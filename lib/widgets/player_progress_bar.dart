import 'package:flutter/material.dart';

/// 播放进度条（纯展示组件）。
///
/// 位置 / 时长 / 跳转回调由外部传入，不依赖播放器 ViewModel，
/// 与 `PlayerControls` 一样放在公共 widgets/ 层（widgets/ 不能反向依赖 features/）。
class PlayerProgressBar extends StatefulWidget {
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

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  /// 拖动中的预览位置（毫秒）；null = 未拖动，显示真实播放位置。
  ///
  /// 拖动时若把每个 onChanged 都直接喂给 `onSeek`，一秒内会对引擎下发几十次
  /// seek（每次都要求原生定位 + 缓冲，期间 UI 还会被滞后回跳的位置拽回去）；
  /// 这里只预览、松手时提交一次（与 `_VolumeSlider` 同一套做法）。
  double? _dragMs;

  @override
  void didUpdateWidget(PlayerProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换曲时 duration 变小：把残留的预览值收进新范围（拖动中不会被外部更新影响）。
    final maxMs = _maxMs;
    if (_dragMs != null && _dragMs! > maxMs) {
      _dragMs = maxMs;
    }
  }

  double get _maxMs {
    final ms = widget.duration.inMilliseconds;
    return ms > 0 ? ms.toDouble() : 1000.0;
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = _maxMs;
    final positionMs = widget.position.inMilliseconds.toDouble().clamp(
      0.0,
      maxMs,
    );
    final sliderValue = (_dragMs ?? positionMs).clamp(0.0, maxMs);
    // 拖动中左侧时间显示预览位置，避免「指针在中间、数字还在旧位置」的割裂。
    final displayPosition = _dragMs != null
        ? Duration(milliseconds: _dragMs!.round())
        : widget.position;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: sliderValue,
            max: maxMs,
            onChangeStart: (v) => setState(() => _dragMs = v),
            onChanged: (v) => setState(() => _dragMs = v),
            onChangeEnd: (v) {
              setState(() => _dragMs = null);
              widget.onSeek(Duration(milliseconds: v.round()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format(displayPosition),
                style: widget.theme.textTheme.bodySmall,
              ),
              Text(
                _format(widget.duration),
                style: widget.theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
