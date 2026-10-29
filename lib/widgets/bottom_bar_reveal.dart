import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 「正在播放」展开/收起过渡：底栏先长成播放页底部的控制带，再把正文从带子上沿
/// 往上揭开（而不是整页从屏幕外滑进来）。
///
/// 高度只用**一条** `easeInOutCubic` 贯通全程（见 [revealHeight]）：
/// - 带子段（[collapsedHeight] → 实测带高，约 80px）占全程距离的 ~10%，在曲线上
///   自然摊到前 ~30% 的时间（≈110ms），所以看得清「带子长出来」；
/// - 之后不会出现两段动画之间的速度归零 —— 那一下停顿就是"顿住再窜"的来源；
/// - 后半段（正文）在 easeInOut 的减速区间，天然是"由快到慢"。
///
/// ⚠️ 起点就是 [collapsedHeight]（不是 0）：底栏必须在页面布局前卸载（否则根
/// Scaffold 的 body 高度会在动画收尾时变一次，页面跟着跳），所以第一帧就得用
/// 页面自己的底部带子盖住底栏原来的位置 —— 两者同宽、同色、同高。
///
/// 实现是**一个**自底向上的裁剪窗口 + 让页面按全屏高度固定布局（[OverflowBox]
/// 底部对齐）—— 每帧只有裁剪面在动，页面不会重排。
///
/// 为了不读成「刷新/擦除」，额外两件事（都只改绘制，不改布局）：
/// - **上沿一条 1px 细线**（[hairlineColor]）：卡片的顶边是"边"，不是"被切开"；
///   （之前试过向底色渐隐，观感偏"擦除"，已弃用）
/// - **整体微缩放**（[pageScaleFor]，0.97 → 1，锚点 bottomCenter）：让整块东西
///   真的有"在动"的证据。锚点在底边，所以带子仍然严格贴底；缩放让出的边角由
///   底层同色的两块垫底（[surface]/[bandColor]）补上，不会露出下面的页面。
/// - **卡片质感**（[cornerRadiusFor] + [surfaceShadow]）：顶角圆角 + 向上投影，
///   让"底栏长成一张卡片"。这两样只在过渡中出现 —— 展开到 100% 时卡片顶边正好
///   到达窗口顶，圆角与投影自动移出视野，静止态与之前完全一致。
/// - **内容整体上浮**（[contentLiftFor]，由页面自己施加在 appBar/body 上，带子
///   不参与）：元素是在"往上走"的，而不是被一条边界扫出来。
class BottomBarReveal extends StatefulWidget {
  const BottomBarReveal({
    super.key,
    required this.animation,
    required this.child,
    this.bandKey,
    this.collapsedHeight = 64,
    this.fallbackBandHeight = 140,
  });

  final Animation<double> animation;
  final Widget child;

  /// 页面底部控制带的 key：量它的真实高度。
  ///
  /// 带高随窗口宽度（宽/窄版控制按钮 64/44）、字号、睡眠定时入口变化，写死常数
  /// 会让「带子阶段」的收尾高度对不上，两段速度之间出现断层。
  final GlobalKey? bandKey;

  /// 收起态高度：迷你底栏 64（见 `NowPlayingBar`）。
  final double collapsedHeight;

  /// 量不到带高时的兜底（例如页面处于空态、没有播放条）。
  final double fallbackBandHeight;

  /// 带内内容淡入完成时的进度（≈ 带子长满的时刻）。
  static const double bandPhase = 0.32;

  /// 卡片顶边细线（[hairlineColor] 用）：底色之外的对比度来源。
  static const double hairlineAlpha = 0.6;

  /// 卡片顶角最大圆角（见 [cornerRadiusFor]）。
  static const double maxCornerRadius = 16;

  /// 卡片顶边细线颜色；收起态/终点返回 null（不画）。
  ///
  /// 与圆角、投影同理：只在过渡中存在 —— 展开到 100% 时顶边已在窗口顶。
  static Color? hairlineColor(ColorScheme scheme, double progress) {
    if (progress <= 0 || progress >= 1) return null;
    return scheme.outlineVariant.withValues(
      alpha: hairlineAlpha * progress.clamp(0.0, 1.0),
    );
  }

  /// 收起箭头的旋转圈数（0 = 朝下，0.5 = 翻到朝上）。
  ///
  /// 顶栏是最后才被揭开的部分：如果按全程线性转头，转完的那一刻顶栏还没露出来
  /// （所以几乎看不到）。收进展开的收尾段（进度 0.8 → 1）才看得见 —— 那时顶栏
  /// 刚好露出，箭头一边就位一边转正。
  static double collapseArrowTurns(double progress) {
    final p = ((progress.clamp(0.0, 1.0) - 0.8) / 0.2).clamp(0.0, 1.0);
    return 0.5 * (1 - Curves.easeOut.transform(p));
  }

  /// 正文整体下移的最大量（进度 0 时），随后一路上浮到 0。
  ///
  /// 只给正文（appBar + body），底部控制带不参与 —— 带子必须始终贴底。取值越大
  /// 「整体升上来」越明显，但过大会让内容在早段被带子盖住太久。
  static const double contentLift = 240;

  /// 进度 [progress] 下正文需要下移的量（progress = 1 时归位到 0）。
  static double contentLiftFor(double progress) {
    final t = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    return contentLift * (1 - t);
  }

  /// 卡片顶角圆角：前 40% 进度内吃到满值，之后保持。
  ///
  /// 收起态必须是 0 —— 那一帧要和迷你底栏像素一致（直边）。
  static double cornerRadiusFor(double progress) {
    final p = (progress.clamp(0.0, 1.0) / 0.4).clamp(0.0, 1.0);
    return maxCornerRadius * Curves.easeOutCubic.transform(p);
  }

  /// 卡片向上投影（3 条 `blurRadius: 0` 实线，透明度 ∝ 进度）。
  ///
  /// 与 `card_surface.dart` 的 [bottomDropShadow] 同一套做法（0 blur，不触发
  /// Impeller 的 SDF blur），只是方向朝上 —— 卡片是压在页面上方的。
  static List<BoxShadow> surfaceShadow(ColorScheme scheme, double progress) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= 0) return const [];
    final shadow = scheme.shadow;
    return [
      BoxShadow(
        color: shadow.withValues(alpha: 0.10 * t),
        blurRadius: 0,
        offset: const Offset(0, -1),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: 0.07 * t),
        blurRadius: 0,
        offset: const Offset(0, -2),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: 0.04 * t),
        blurRadius: 0,
        offset: const Offset(0, -3),
      ),
    ];
  }

  /// 带内内容淡入/淡出结束的进度（≈ 全程的 4%，正常速度下约 15ms ≈ 1 帧）。
  ///
  /// 必须**极短**：它只为掩盖"第一帧带子被裁掉半截"（展开）与最后几帧同样的
  /// 裁切（收起）。淡出窗口越长，"带子空了、底栏还没挂上"的空条就越明显 ——
  /// 那一段看起来就像控制栏比界面先消失。
  static const double bandFadePhase = 0.04;

  /// 带内内容的淡入不透明度（含进度条与控制行）。
  ///
  /// 0 → 1 都收在 [bandFadePhase] 里：起点 0 让第一帧只剩一条纯色带子（与刚
  /// 淡出的底栏无缝），之后全程保持 1，直到收起时的最后一段才淡掉。
  static double bandContentOpacity(double progress) {
    return (progress.clamp(0.0, 1.0) / bandFadePhase).clamp(0.0, 1.0);
  }

  /// 进度 [progress] 下、从屏幕底部起算的可见高度。
  ///
  /// 起点是 [collapsedHeight]（页面自己的带子先盖住底栏原位置）；返回
  /// `viewportHeight` 时铺满。
  ///
  /// 全程一条 `easeInOutCubic`，**没有分段**：带子那 80px 由它在距离上的占比
  /// 自然摊成前 ~30% 时间，之后一路减速到落位，中间没有速度归零的停顿。
  static double revealHeight(
    double progress,
    double viewportHeight, {
    double collapsedHeight = 64,
  }) {
    final height = viewportHeight;
    if (height <= 0) return 0;

    final start = math.min(collapsedHeight, height);
    final t = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    return start + (height - start) * t;
  }

  /// 页面整体缩放（锚点 bottomCenter）：0.97 → 1，只在正文阶段变化。
  ///
  /// 底边固定 → 底部控制带仍然贴底；缓动与 [revealHeight] 第二段一致，两者同步
  /// 收敛，观感是"升起来并落位"。
  static double pageScaleFor(double progress) {
    final p = progress.clamp(0.0, 1.0);
    if (p <= bandPhase) return 0.97;
    final t = Curves.easeInOutCubic.transform(
      (p - bandPhase) / (1 - bandPhase),
    );
    return 0.97 + 0.03 * t;
  }

  @override
  State<BottomBarReveal> createState() => _BottomBarRevealState();
}

class _BottomBarRevealState extends State<BottomBarReveal> {
  double? _bandHeight;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(BottomBarReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  /// 每次开始进场都重新量一次（窗口宽窄、字号可能在两次打开之间变过）。
  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) _scheduleMeasure();
  }

  void _scheduleMeasure() {
    final key = widget.bandKey;
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || box.size.height <= 0) return;
      if (box.size.height == _bandHeight) return;
      setState(() => _bandHeight = box.size.height);
    });
  }

  /// 给表面套上卡片外观：顶角圆角 + 向上投影（两者都是 0 时直接返回 child）。
  Widget _cardSurface({
    required Widget child,
    required double radius,
    required List<BoxShadow> shadows,
  }) {
    final borderRadius = BorderRadius.vertical(top: Radius.circular(radius));
    var surface = child;
    if (radius > 0.5) {
      surface = ClipRRect(borderRadius: borderRadius, child: surface);
    }
    if (shadows.isNotEmpty) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: shadows,
        ),
        child: surface,
      );
    }
    return surface;
  }

  @override
  Widget build(BuildContext context) {
    final bandHeight = _bandHeight ?? widget.fallbackBandHeight;
    final scheme = Theme.of(context).colorScheme;
    // 垫底色：与播放页自身一致（Scaffold 用 surface，底部控制带用
    // surfaceContainerLow），缩放让出的边角就由这两块补上，不会露出下层页面。
    final pageBackground = scheme.surface;
    final bandColor = scheme.surfaceContainerLow;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return AnimatedBuilder(
          animation: widget.animation,
          // 页面作为 child 透传：裁剪面/缩放变化不触发页面重建。
          child: widget.child,
          builder: (context, child) {
            final progress = widget.animation.value;
            final reveal = BottomBarReveal.revealHeight(
              progress,
              height,
              collapsedHeight: widget.collapsedHeight,
            ).clamp(0.0, height);
            final scale = BottomBarReveal.pageScaleFor(progress);
            // 终点（进度 1）不挂圆角/投影：卡片顶边已到窗口顶，视觉上等价，
            // 但少一层裁剪，静止态渲染与改动前逐像素一致。
            final radius = progress >= 1
                ? 0.0
                : BottomBarReveal.cornerRadiusFor(progress);
            final shadows = BottomBarReveal.surfaceShadow(scheme, progress);
            final hairline = BottomBarReveal.hairlineColor(scheme, progress);

            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: reveal,
                    child: _cardSurface(
                      radius: radius,
                      shadows: shadows,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 垫底：上半页面底色、下半控制带色（缩放后补边角用）。
                          ColoredBox(color: pageBackground),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: (bandHeight * scale).clamp(0.0, reveal),
                            child: ColoredBox(color: bandColor),
                          ),
                          ClipRect(
                            // 页面按全屏高度布局后底部对齐，再由裁剪窗口从下往上露出；
                            // 缩放锚点在底边 → 控制带始终严格贴底。
                            child: OverflowBox(
                              alignment: Alignment.bottomCenter,
                              minWidth: width,
                              maxWidth: width,
                              minHeight: height,
                              maxHeight: height,
                              child: Transform.scale(
                                scale: scale,
                                alignment: Alignment.bottomCenter,
                                // 页面自成合成层：缩放只改变换矩阵，页面内容按原
                                // 尺寸光栅化一次，避免逐帧重画整窗口。
                                child: RepaintBoundary(child: child),
                              ),
                            ),
                          ),
                          // 卡片顶边细线：让裁切线读成"边"，而不是"被切开"。
                          if (hairline != null)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              height: 1,
                              child: IgnorePointer(
                                child: ColoredBox(color: hairline),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
