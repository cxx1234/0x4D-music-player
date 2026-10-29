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
    ValueNotifier<bool>? revealed,
    GlobalKey? bandKey,
    VoidCallback? onDisposed,
  }) {
    return _DeferredStartRoute<void>(
      revealed: revealed,
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

/// 首帧之后再启动转场动画。
///
/// 页面 build + first layout 很贵（冷启动实测 40~90ms，约 5 个 vsync）。
/// `TransitionRoute.didPush` 会在同一帧就 `forward()`，`AnimationController` 按
/// 真实时间推进 —— 等这一帧画完，进度已经跳到 20% 上下，用户看到的是「卡一下
/// 然后动画从中间开始」，前半段被整段吞掉。
///
/// 这里把启动推迟到首帧结束（页面已按 progress=0 完成布局），进度从 0 连续走。
class _DeferredStartRoute<T> extends PageRouteBuilder<T> {
  _DeferredStartRoute({
    super.settings,
    required super.pageBuilder,
    required super.transitionsBuilder,
    required super.transitionDuration,
    required super.reverseTransitionDuration,
    this.revealed,
  });

  /// 展开动画走完时置 true（页面据此挂上延迟构建的内容）。
  final ValueNotifier<bool>? revealed;

  /// `TransitionRoute.animation` 暴露的是 `_controller.view`（不是控制器），
  /// 所以必须在创建时把控制器本身留下来。
  AnimationController? _controller;

  @override
  AnimationController createAnimationController() {
    final controller = super.createAnimationController();
    _controller = controller;
    return controller;
  }

  @override
  TickerFuture didPush() {
    final ticker = super.didPush();
    final controller = _controller;
    if (controller == null) return ticker;
    // super.didPush() 已经 forward()：同一帧内先停住（还没 tick 过，仍在 0），
    // 等页面首帧布局完成后再放行。canceled: false —— 让 didPush 返回的
    // TickerFuture 正常完成，`Navigator` 的 whenCompleteOrCancel 才会把
    // 路由状态从 pushing 收回 idle。
    controller.stop(canceled: false);
    final revealed = this.revealed;
    if (revealed != null) {
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) revealed.value = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // value >= 1：动画已经走完（不该再启动）；isAnimating：已经被放行过。
      if (!isActive || controller.isAnimating || controller.value >= 1) return;
      controller.forward();
    });
    return ticker;
  }
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
