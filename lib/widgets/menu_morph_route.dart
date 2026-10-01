import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 「容器变换」（Material Motion 的 container transform）弹出的菜单。
///
/// 与 `PopupMenuButton` 的区别：面板不是"在某个位置淡入或滑入"，而是**从触发它的
/// 那个矩形连续长出来**——位置与尺寸用 [RectTween] 插值、圆角用 [ShapeBorderTween]
/// （胶囊 → 面板）、底色用 [ColorTween]，内容在面板里淡入。
///
/// 关键在于**锚点那一角在整段动画里不动**（向上长时钉住左下角、向下长时钉住
/// 左上角），并且内容按终点尺寸、贴着同一个角布局 —— 于是内容在屏幕上是不动的，
/// 只是被面板的裁剪逐步揭示。这正是它看起来"从按钮长出来"而不是"从屏幕边缘滑
/// 进来"的原因。
///
/// ### 为什么不用 `package:animations` 的 `OpenContainer`
///
/// 它的终点矩形是写死的全屏（`open_container.dart` 里 `_rectTween.end =
/// Offset.zero & navSize`），只适合"小控件 → 整页"的容器变换，做不了贴着按钮的
/// 小菜单。这里自己控制起点/终点与屏幕边距钳制。
///
/// ### 与 `PopupMenuRoute` 的另一个差别
///
/// `PopupMenuRoute` 的定位每帧都用**当帧尺寸**重算（`_fitInsideScreen`），菜单比
/// 按钮下方空间高时会被"底边钉住、整张菜单从窗口下沿滑上来"；这里的位置只算一次，
/// 面板靠自身的裁剪长大，不会有那种位移。
class MenuMorphRoute<T> extends PopupRoute<T> {
  MenuMorphRoute({
    required this.anchorRect,
    required this.panelSize,
    required this.builder,
    this.anchorShape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    ),
    this.panelShape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    this.anchorColor,
    this.panelColor,
    this.duration = const Duration(milliseconds: 320),
    this.reverseDuration = const Duration(milliseconds: 220),
  });

  /// 触发它的控件在 **overlay 坐标**里的矩形（动画起点）。
  final Rect anchorRect;

  /// 面板的期望尺寸。屏幕放不下时会被钳制（内容由调用方自己负责滚动）。
  final Size panelSize;

  /// 菜单内容；`close` 关闭并把值回传给 `Navigator.push` 的 future。
  final Widget Function(BuildContext context, void Function([T? result]) close)
  builder;

  final ShapeBorder anchorShape;
  final ShapeBorder panelShape;

  /// 起点 / 终点底色；null 时取 `surfaceContainerHigh` / `surfaceContainer`。
  final Color? anchorColor;
  final Color? panelColor;

  /// 打开时长。
  final Duration duration;

  /// 关闭时长；通常比打开短（两者可以不一样，这是弹层菜单给不了的）。
  final Duration reverseDuration;

  CurvedAnimation? _curved;

  /// 只在创建时套一次曲线：`CurvedAnimation` 会给父级挂监听，每帧新建而不
  /// dispose 会一直泄漏。
  @override
  Animation<double> createAnimation() {
    return _curved ??= CurvedAnimation(
      parent: super.createAnimation(),
      curve: Curves.fastOutSlowIn,
      // 关闭用同一条曲线的镜像，避免反向时"先愣一下"。
      reverseCurve: Curves.fastOutSlowIn.flipped,
    );
  }

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => reverseDuration;

  @override
  bool get barrierDismissible => true;

  /// 不变暗：与弹出菜单一致，点外面只是关掉。
  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  void dispose() {
    _curved?.dispose();
    super.dispose();
  }

  /// 页面本身是空的，全部内容都在 [buildTransitions] 里画。
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const SizedBox.shrink();

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _MorphGeometry.resolve(
          viewport: Size(constraints.maxWidth, constraints.maxHeight),
          anchorRect: anchorRect,
          panelSize: panelSize,
        );

        // 内容按终点尺寸布局、钉在"生长方向那一角"——这样面板长大时它在屏幕上
        // 不动，只被裁剪逐步揭示。放在 AnimatedBuilder 外面，避免每帧重建。
        final content = SizedBox(
          width: geometry.endRect.width,
          height: geometry.endRect.height,
          child: builder(
            context,
            ([T? result]) => Navigator.of(context).pop(result),
          ),
        );
        final contentLayer = geometry.growsUp
            ? Positioned(
                left: 0,
                bottom: 0,
                width: geometry.endRect.width,
                height: geometry.endRect.height,
                child: content,
              )
            : Positioned(
                left: 0,
                top: 0,
                width: geometry.endRect.width,
                height: geometry.endRect.height,
                child: content,
              );

        return AnimatedBuilder(
          animation: animation,
          child: contentLayer,
          builder: (context, child) {
            final rect = RectTween(
              begin: anchorRect,
              end: geometry.endRect,
            ).evaluate(animation)!;
            final shape = ShapeBorderTween(
              begin: anchorShape,
              end: panelShape,
            ).evaluate(animation)!;
            final color = ColorTween(
              begin: anchorColor ?? scheme.surfaceContainerHigh,
              end: panelColor ?? scheme.surfaceContainer,
            ).evaluate(animation);
            // 内容在面板里淡入；还没淡完时不接受点击，避免点到"看不见的条目"。
            final contentOpacity = const Interval(
              0.25,
              1,
            ).transform(animation.value);

            return Align(
              alignment: Alignment.topLeft,
              child: Stack(
                children: [
                  Positioned.fromRect(
                    rect: rect,
                    child: Material(
                      color: color,
                      elevation: 3,
                      clipBehavior: Clip.antiAlias,
                      shape: shape,
                      child: IgnorePointer(
                        ignoring: contentOpacity < 1,
                        child: Opacity(
                          opacity: contentOpacity,
                          child: Stack(children: [child!]),
                        ),
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

/// 一次打开的面板几何：夹进屏幕后的终点矩形 + 生长方向。
@immutable
class _MorphGeometry {
  const _MorphGeometry({required this.endRect, required this.growsUp});

  final Rect endRect;
  final bool growsUp;

  /// 屏幕边距（面板不贴边）。
  static const double _kMargin = 8;

  static _MorphGeometry resolve({
    required Size viewport,
    required Rect anchorRect,
    required Size panelSize,
  }) {
    // 竖向：优先往下长；下面装不下就翻到上方（钉住两者共有的那条边）。
    final double spaceBelow = viewport.height - _kMargin - anchorRect.bottom;
    final bool growsUp = panelSize.height > spaceBelow;
    final double available = growsUp
        ? anchorRect.bottom - _kMargin
        : spaceBelow;
    final double height = math.min(panelSize.height, math.max(available, 0));
    // 横向：左边缘与锚点左边缘对齐；右边缘装不下就往左挪。
    final double width = math.min(
      panelSize.width,
      math.max(viewport.width - 2 * _kMargin, 0),
    );
    final double left = anchorRect.left + width <= viewport.width - _kMargin
        ? anchorRect.left
        : math.max(_kMargin, viewport.width - _kMargin - width);

    return _MorphGeometry(
      growsUp: growsUp,
      endRect: growsUp
          ? Rect.fromLTWH(left, anchorRect.bottom - height, width, height)
          : Rect.fromLTWH(left, anchorRect.top, width, height),
    );
  }
}
