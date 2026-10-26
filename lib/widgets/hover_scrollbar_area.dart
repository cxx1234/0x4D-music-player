import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 桌面端滚动条：鼠标进入本区域时显示，离开时隐藏。
///
/// 默认的 [Scrollbar] 会在每次程序化滚动（例如歌词跟唱换行）时淡入淡出，
/// 表现为每换一行闪一下。这里保留 [MaterialScrollBehavior] 的其余行为，
/// 只把滚动条的可见性绑到区域悬停状态；移动端保持系统默认（无滚动条）。
class HoverScrollbarArea extends StatefulWidget {
  const HoverScrollbarArea({super.key, required this.child});

  final Widget child;

  @override
  State<HoverScrollbarArea> createState() => _HoverScrollbarAreaState();
}

class _HoverScrollbarAreaState extends State<HoverScrollbarArea> {
  /// 只驱动滚动条显隐，不重建子树。
  final ValueNotifier<bool> _hovering = ValueNotifier(false);

  @override
  void dispose() {
    _hovering.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hovering.value = true,
      onExit: (_) => _hovering.value = false,
      child: ScrollConfiguration(
        behavior: _HoverScrollbarBehavior(_hovering),
        child: widget.child,
      ),
    );
  }
}

class _HoverScrollbarBehavior extends MaterialScrollBehavior {
  const _HoverScrollbarBehavior(this.hovering);

  final ValueListenable<bool> hovering;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) != Axis.vertical) return child;
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        final controller = details.controller;
        if (controller == null) return child;
        return _HoverScrollbar(
          controller: controller,
          hovering: hovering,
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}

class _HoverScrollbar extends StatefulWidget {
  const _HoverScrollbar({
    required this.controller,
    required this.hovering,
    required this.child,
  });

  final ScrollController controller;
  final ValueListenable<bool> hovering;
  final Widget child;

  @override
  State<_HoverScrollbar> createState() => _HoverScrollbarState();
}

class _HoverScrollbarState extends State<_HoverScrollbar> {
  /// 拖拽滑块时即使鼠标滑出区域也保持可见。
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.hovering,
      builder: (context, hovering, _) {
        final show = (hovering || _dragging) && widget.controller.hasClients;
        final theme = ScrollbarTheme.of(context);
        return ScrollbarTheme(
          // 不悬停时把滑块设为透明：程序化滚动仍会让 Scrollbar 走一遍淡入
          // 动画，透明色保证它不会再「闪一下」；悬停时沿用主题原本的颜色。
          data: show
              ? theme
              : theme.copyWith(
                  thumbColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: Scrollbar(
              controller: widget.controller,
              thumbVisibility: show,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _setDragging(notification.dragDetails != null);
    } else if (notification is ScrollEndNotification) {
      _setDragging(false);
    }
    return false;
  }

  void _setDragging(bool value) {
    if (_dragging == value) return;
    setState(() => _dragging = value);
  }
}
