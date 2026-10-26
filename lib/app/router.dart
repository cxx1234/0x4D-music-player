import 'package:flutter/material.dart';

import '../widgets/bottom_bar_reveal.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const SizedBox.shrink(),
      settings: settings,
    );
  }

  /// 「正在播放」展开/收起：迷你底栏（64）先长成播放页底部的控制带，正文随后从
  /// 带子上沿往上揭开（见 [BottomBarReveal]），不再整页从屏幕外滑进来。
  ///
  /// Step 1（方向验证）：只做几何 —— 带子与正文的内容不做交叉淡入，pop 走同一条
  /// 曲线反向。
  ///
  /// [progress] 把路由进度同步给页外元素（根 Scaffold 的迷你底栏据此淡出内容）；
  /// [bandKey] 指向播放页底部控制带，用于量它的真实高度（见 [BottomBarReveal]）。
  /// [onDisposed] 在路由销毁时回调（含 `pushAndRemoveUntil` 这类不走动画的替换），
  /// 供调用方把进度归零。
  ///
  /// 逐帧检查中间态：`flutter run --dart-define=PLAYER_REVEAL_SLOW=true`（时长 ×4）。
  static Route<void> bottomUpRoute(
    Widget page, {
    String? name,
    ValueNotifier<double>? progress,
    GlobalKey? bandKey,
    VoidCallback? onDisposed,
  }) {
    return PageRouteBuilder<void>(
      settings: name != null ? RouteSettings(name: name) : null,
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final reveal = BottomBarReveal(
          animation: animation,
          bandKey: bandKey,
          child: child,
        );
        if (progress == null) return reveal;
        return _ProgressMirror(
          animation: animation,
          target: progress,
          onDisposed: onDisposed,
          child: reveal,
        );
      },
    );
  }

  static const Duration _duration = Duration(milliseconds: 380);

  static const bool _slowMotion = bool.fromEnvironment('PLAYER_REVEAL_SLOW');

  /// 播放页展开/收起的单程时长（含慢放开关的影响）。
  static Duration get transitionDuration => _transitionDuration;

  static Duration get _transitionDuration =>
      _slowMotion ? _duration * 4 : _duration;
}

/// 把路由动画进度镜像到外部 notifier；路由销毁时通知调用方复位。
class _ProgressMirror extends StatefulWidget {
  const _ProgressMirror({
    required this.animation,
    required this.target,
    required this.child,
    this.onDisposed,
  });

  final Animation<double> animation;
  final ValueNotifier<double> target;
  final VoidCallback? onDisposed;
  final Widget child;

  @override
  State<_ProgressMirror> createState() => _ProgressMirrorState();
}

class _ProgressMirrorState extends State<_ProgressMirror> {
  void _sync() => widget.target.value = widget.animation.value;

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_sync);
    // 路由在 push 过程中挂载（正处在 build 期间），此刻直接写 notifier 会触发
    // 「build 期间 setState」—— 同步动作排到帧后。
    final current = widget.animation.value;
    if (current != widget.target.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.target.value = current;
      });
    }
  }

  @override
  void didUpdateWidget(_ProgressMirror oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_sync);
      widget.animation.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_sync);
    widget.onDisposed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
