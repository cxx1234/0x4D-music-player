import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/services/playback_feedback_service.dart';

/// 让屏幕上的按钮响应「外部操作」（快捷键 / 媒体键 / 系统「正在播放」面板）。
///
/// 外部操作不经过按钮本身，InkWell 的水波自然不会出现；这里用一次 [duration]
/// 的缩放 + 高亮补上「我响应了」的反馈 —— `builder` 的 `pulsing` 为 true 期间，
/// 调用方按需把按钮切到高亮样式（如 `_ControlButton` 的激活态）。
class ControlPulse extends StatefulWidget {
  const ControlPulse({
    super.key,
    required this.pulses,
    required this.action,
    required this.builder,
    this.duration = const Duration(milliseconds: 180),
  });

  /// 脉冲源；null = 不接（例如服务尚未就绪）。
  final ValueListenable<PlaybackPulse?>? pulses;

  /// 只响应这一个动作。
  final PlaybackAction action;

  /// `pulsing` = 本次脉冲动画进行中。
  final Widget Function(BuildContext context, bool pulsing) builder;

  final Duration duration;

  @override
  State<ControlPulse> createState() => _ControlPulseState();
}

class _ControlPulseState extends State<ControlPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// 按下 → 回弹：先压到 0.9，再带一点回弹余量回到 1.0。
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0.9,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.9,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 65,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    widget.pulses?.addListener(_onPulse);
  }

  @override
  void didUpdateWidget(ControlPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulses != widget.pulses) {
      oldWidget.pulses?.removeListener(_onPulse);
      widget.pulses?.addListener(_onPulse);
    }
  }

  @override
  void dispose() {
    widget.pulses?.removeListener(_onPulse);
    _controller.dispose();
    super.dispose();
  }

  void _onPulse() {
    final pulse = widget.pulses?.value;
    if (pulse == null || pulse.action != widget.action) return;
    // 连续脉冲从头重放；动画期间 `isAnimating` 为 true，高亮随之保持。
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ScaleTransition(
        scale: _scale,
        child: widget.builder(context, _controller.isAnimating),
      ),
    );
  }
}
