import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 拖动式索引滚动条：接管列表右侧滚动条。
///
/// 平时是**普通滑块**（overlay 显示：滚动时出现、鼠标悬停时出现，静止后
/// 隐藏）；支持**拖动滑块**与**点击轨道**跳转滚动；拖动时若
/// [letterOfIndex] 返回非空，则在滑块左侧弹出当前索引字母气泡
/// （A-Z / 五十音行 / #），松手后淡出。
///
/// 用法：列表（ListView/GridView）须同时设置 `controller: widget.controller`、
/// `itemExtent` 与 `scrollBehavior: const ScrollBehavior(scrollbars: false)`
/// （禁用系统默认滚动条，避免双滚动条重叠）。
class IndexScrollbar extends StatefulWidget {
  const IndexScrollbar({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.letterOfIndex,
    required this.child,
    this.itemExtent = 72.0,
  });

  /// 列表滚动控制器（须同时传给列表的 `controller`）。
  final ScrollController controller;

  /// 列表总行数。
  final int itemCount;

  /// 每行高度（固定行高），用于把滚动 offset 换算为当前行 index。
  final double itemExtent;

  /// 返回第 [index] 行的索引字母；返回 null 表示该列表无字母概念
  /// （如非标题排序），此时拖动滑块不弹气泡、纯普通滑块。
  final String? Function(int index) letterOfIndex;

  /// 列表本体。
  final Widget child;

  @override
  State<IndexScrollbar> createState() => _IndexScrollbarState();
}

class _IndexScrollbarState extends State<IndexScrollbar> {
  /// 轨道命中区宽度（含 thumb 与两侧空隙）。落在列表右 padding 内，
  /// 不遮挡行内交互（如行尾菜单）。
  static const double _hitWidth = 14.0;
  static const double _thumbWidth = 6.0;
  static const double _thumbWidthHover = 10.0;
  static const double _bubbleGap = 10.0;
  static const double _bubbleSize = 64.0;
  static const double _minThumbHeight = 56.0;

  /// 滚动停止后滑块隐藏延迟。
  static const Duration _hideDelay = Duration(milliseconds: 900);

  /// 鼠标离开轨道后滑块隐藏延迟。
  static const Duration _hoverHideDelay = Duration(milliseconds: 500);

  /// 气泡淡入/淡出时长。
  static const Duration _bubbleFadeDuration = Duration(milliseconds: 200);

  /// 拖拽结束后气泡卸载延迟（先淡出再卸载）。
  static const Duration _bubbleHideDelay = Duration(milliseconds: 350);

  bool _visible = false;
  bool _hovering = false;
  bool _dragging = false;
  Timer? _hideTimer;

  String? _bubbleLetter;
  bool _bubbleFading = false;
  double _bubbleFraction = 0.0;
  Timer? _bubbleHideTimer;

  double _dragStartOffset = 0;
  double _dragStartY = 0;
  double _trackHeight = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(IndexScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    _hideTimer?.cancel();
    _bubbleHideTimer?.cancel();
    super.dispose();
  }

  // ─── 可见性（overlay） ─────────────────────────────────

  void _handleScroll() {
    if (_dragging) return;
    _showThumb(scheduleHide: true);
  }

  void _showThumb({bool scheduleHide = false}) {
    if (!_visible) setState(() => _visible = true);
    _hideTimer?.cancel();
    if (scheduleHide) _hideTimer = Timer(_hideDelay, _hideThumb);
  }

  void _hideThumb() {
    if (!mounted || _hovering || _dragging) return;
    setState(() => _visible = false);
  }

  void _onHoverEnter(PointerEnterEvent _) {
    // hover 时始终重建，让 thumb 加宽/加深即时生效（此前只在自己恰好触发
    // visible setState 时才有效果，导致 hover 时有时无）。
    setState(() {
      _hovering = true;
      _visible = true;
    });
    _hideTimer?.cancel();
  }

  void _onHoverExit(PointerExitEvent _) {
    setState(() => _hovering = false);
    if (_dragging) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(_hoverHideDelay, _hideThumb);
  }

  // ─── 滚动几何 ───────────────────────────────────────────

  double get _maxScroll {
    if (!widget.controller.hasClients) return 0;
    return widget.controller.position.maxScrollExtent;
  }

  double get _offset {
    if (!widget.controller.hasClients) return 0;
    return widget.controller.position.pixels;
  }

  double _thumbHeight() {
    if (!widget.controller.hasClients || _maxScroll <= 0) return _trackHeight;
    final viewport = widget.controller.position.viewportDimension;
    final fraction = viewport / (_maxScroll + viewport);
    // 柄高按比例 ×2（比默认滚动条更易抓取）；最小高度同步翻倍。
    return (_trackHeight * fraction * 2).clamp(_minThumbHeight, _trackHeight);
  }

  double _thumbTop(double thumbHeight) {
    if (_maxScroll <= 0) return 0;
    return (_trackHeight - thumbHeight) * (_offset / _maxScroll);
  }

  // ─── 拖拽 / 点轨道 ──────────────────────────────────────

  void _onDragStart(DragStartDetails details) {
    _dragging = true;
    _hideTimer?.cancel();
    _showThumb();
    final position = widget.controller.position;
    final localY = details.localPosition.dy;
    final thumbHeight = _thumbHeight();
    final thumbTop = _thumbTop(thumbHeight);
    if (localY >= thumbTop && localY <= thumbTop + thumbHeight) {
      // 按下在滑块内：保持当前滚动位置作为拖拽锚点。
      _dragStartOffset = position.pixels;
    } else {
      // 按下在轨道空白处：先跳到对应比例位置，再以此为锚点继续拖。
      final target = (localY / _trackHeight * position.maxScrollExtent).clamp(
        0.0,
        position.maxScrollExtent,
      );
      _dragStartOffset = target;
      position.jumpTo(target);
    }
    _dragStartY = localY;
    _updateBubble();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final position = widget.controller.position;
    final thumbHeight = _thumbHeight();
    final travel = _trackHeight - thumbHeight;
    if (travel <= 0) return;
    final delta = details.localPosition.dy - _dragStartY;
    final target =
        (_dragStartOffset + delta / travel * position.maxScrollExtent).clamp(
          0.0,
          position.maxScrollExtent,
        );
    position.jumpTo(target);
    setState(() {
      _bubbleFraction = (details.localPosition.dy / _trackHeight).clamp(
        0.0,
        1.0,
      );
    });
    _updateBubble();
  }

  void _onDragEnd(DragEndDetails details) => _endDrag();

  void _onDragCancel() => _endDrag();

  void _endDrag() {
    _dragging = false;
    if (_bubbleLetter != null) {
      setState(() => _bubbleFading = true);
      _bubbleHideTimer?.cancel();
      _bubbleHideTimer = Timer(_bubbleHideDelay, () {
        if (mounted) setState(() => _bubbleLetter = null);
      });
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, _hideThumb);
  }

  void _updateBubble() {
    final index = (_offset / widget.itemExtent).round().clamp(
      0,
      widget.itemCount - 1,
    );
    final letter = widget.letterOfIndex(index);
    if (letter == null) {
      if (_bubbleLetter != null) setState(() => _bubbleLetter = null);
      return;
    }
    if (_bubbleLetter != letter || _bubbleFading) {
      setState(() {
        _bubbleLetter = letter;
        _bubbleFading = false;
      });
    }
    _bubbleHideTimer?.cancel();
  }

  // ─── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _trackHeight = constraints.maxHeight;
        final canScroll = _maxScroll > 0;
        return Stack(
          children: [
            // 禁用系统默认滚动条，由本组件接管右侧滑块（Flutter 3.47 的
            // ListView/GridView 已不再暴露 scrollBehavior 参数，改包
            // ScrollConfiguration 关闭）。
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: widget.child,
            ),
            // 滑块位置/高度随滚动实时更新：用 ListenableBuilder 监听
            // controller，滚动时只重建滑块（不重建列表），滚轮滚动时
            // thumb 也能跟着走。
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                // 轨道常驻（hover 随时可重新显示滑块），thumb 可见性由
                // _visible 经 AnimatedOpacity 控制。
                if (!canScroll) return const SizedBox.shrink();
                return _buildTrack(theme);
              },
            ),
            if (_bubbleLetter != null) _buildBubble(theme),
          ],
        );
      },
    );
  }

  Widget _buildTrack(ThemeData theme) {
    final thumbHeight = _thumbHeight();
    final top = _thumbTop(thumbHeight);
    final active = _hovering || _dragging;
    final width = active ? _thumbWidthHover : _thumbWidth;
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: _hitWidth,
      child: MouseRegion(
        onEnter: _onHoverEnter,
        onExit: _onHoverExit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          onVerticalDragCancel: _onDragCancel,
          child: Stack(
            children: [
              Positioned(
                key: const ValueKey('index-scrollbar-thumb'),
                top: top,
                height: thumbHeight,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: width,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: active ? 0.5 : 0.32,
                        ),
                        borderRadius: BorderRadius.circular(width / 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(ThemeData theme) {
    final letter = _bubbleLetter!;
    final top = (_trackHeight - _bubbleSize) * _bubbleFraction;
    return Positioned(
      right: _hitWidth + _bubbleGap,
      top: top,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _bubbleFading ? 0.0 : 1.0,
          duration: _bubbleFadeDuration,
          child: Container(
            width: _bubbleSize,
            height: _bubbleSize,
            decoration: BoxDecoration(
              // 用主题色，后期主题色设置生效后气泡自动跟随。
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
