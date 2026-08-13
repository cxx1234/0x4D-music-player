import 'dart:async';

import 'package:flutter/material.dart';

/// 垂直方向「淡出 + 塌陷」动画容器。
///
/// [visible] 变化时：
/// - 变为 false：内容先淡出（[fadeDuration]），淡出结束后卸载内容并触发
///   高度塌陷（[collapseDuration]），下方内容随之平滑上移（平移效果）；
/// - 变为 true：内容恢复并同时展开 + 淡入。
///
/// 用于搜索模式下隐藏「非搜索结果区块」（沙箱警告/扫描进度/扫描结果/
/// 文件夹列表等），隐藏后内容彻底卸载，不参与 build 与布局。
///
/// ⚠️ 注意：`child` 在隐藏期间**仍会被父级构建**（淡出结束后才卸载），
/// 因此区块的构建函数必须能容忍其可见性条件不成立的情况——若内部依赖
/// 可空数据，请用 `if (xxx == null) return SizedBox.shrink();` 安全解包，
/// 不要使用 `!` 空断言。
///
/// 注意：本组件面向普通 Box 布局（Column/Row 内）；sliver 内请改用
/// `SliverAnimatedSize` 自行处理。
class AnimatedCollapse extends StatefulWidget {
  const AnimatedCollapse({
    super.key,
    required this.visible,
    required this.child,
    this.collapseDuration = const Duration(milliseconds: 250),
    this.fadeDuration = const Duration(milliseconds: 200),
    this.curve = Curves.easeInOutCubic,
  });

  final bool visible;
  final Widget child;

  /// 高度塌陷/展开的动画时长。
  final Duration collapseDuration;

  /// 淡出/淡入的动画时长（塌陷前先淡出）。
  final Duration fadeDuration;

  final Curve curve;

  @override
  State<AnimatedCollapse> createState() => _AnimatedCollapseState();
}

class _AnimatedCollapseState extends State<AnimatedCollapse> {
  /// 内容是否仍挂载在树中（隐藏时淡出结束后置 false 触发塌陷）。
  bool _rendered = true;
  Timer? _unmountTimer;

  @override
  void initState() {
    super.initState();
    _rendered = widget.visible;
  }

  @override
  void didUpdateWidget(AnimatedCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unmountTimer?.cancel();
    _unmountTimer = null;

    if (widget.visible && !oldWidget.visible) {
      // 展开前恢复内容（didUpdateWidget 后框架必然重建）。
      _rendered = true;
    } else if (!widget.visible && oldWidget.visible) {
      // 先淡出（内容仍在），淡出结束卸载内容触发 AnimatedSize 塌陷。
      _unmountTimer = Timer(widget.fadeDuration, () {
        if (mounted && !widget.visible) setState(() => _rendered = false);
      });
    }
  }

  @override
  void dispose() {
    _unmountTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: widget.collapseDuration,
      curve: widget.curve,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: widget.fadeDuration,
        curve: widget.curve,
        child: _rendered ? widget.child : const SizedBox.shrink(),
      ),
    );
  }
}
