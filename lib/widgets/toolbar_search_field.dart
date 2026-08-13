import 'package:flutter/material.dart';

/// 页面标题栏内的搜索框组件（配合 `PageToolbar.actions` 使用）。
///
/// - **宽度弹性**：最小固定 [minWidth]；最大为窗口宽度的 [maxWidthFactor]
///   倍（窗口最大化时搜索框随之变宽，小窗口时保持最小宽度）。
/// - 内部带放大镜前缀图标；有输入时右侧显示清空按钮（点击清空回到全部）；
///   外部右侧带关闭按钮，点击触发 [onClose] 退出搜索模式（用于恢复原功能区按钮）。
/// - 自带 [TextEditingController]，父组件无需管理；输入变化经 [onChanged] 上报。
class ToolbarSearchField extends StatefulWidget {
  const ToolbarSearchField({
    super.key,
    required this.onChanged,
    required this.onClose,
    this.hintText = '搜索',
    this.minWidth = 240,
    this.maxWidthFactor = 0.4,
  });

  /// 输入变化回调（传入原始文本，父组件自行 trim/归一化）。
  final ValueChanged<String> onChanged;

  /// 点击关闭按钮时回调（退出搜索模式）。
  final VoidCallback onClose;

  final String hintText;

  /// 最小宽度（小窗口/内容不足时保持）。
  final double minWidth;

  /// 最大宽度 = 窗口宽度 × [maxWidthFactor]（最大化窗口时生效）。
  final double maxWidthFactor;

  @override
  State<ToolbarSearchField> createState() => _ToolbarSearchFieldState();
}

class _ToolbarSearchFieldState extends State<ToolbarSearchField> {
  final _controller = TextEditingController();

  /// 正在折叠动画中（点关闭后先折叠回 0，动画结束再回调 [ToolbarSearchField.onClose]）。
  bool _closing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  void _close() {
    if (_closing) return;
    setState(() => _closing = true);
  }

  @override
  Widget build(BuildContext context) {
    // 搜索框位于 PageToolbar 的 Row 内，横向约束可能是 unbounded，
    // 因此以窗口宽度为基准计算弹性宽度（最大化窗口时变宽）。
    final windowWidth = MediaQuery.sizeOf(context).width;
    final width = windowWidth <= widget.minWidth
        ? windowWidth
        : (windowWidth * widget.maxWidthFactor).clamp(
            widget.minWidth,
            windowWidth,
          );

    // 变长展开/折叠动画：挂载时从 0 展开到目标宽度并淡入（Align
    // widthFactor 缩放+ClipRect 裁剪，内容不重排不溢出）；点关闭时折叠
    // 回 0，动画结束再回调 onClose 让父组件移除搜索模式。
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _closing ? 0 : width),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      onEnd: () {
        if (_closing) widget.onClose();
      },
      builder: (context, value, child) {
        final fraction = width <= 0 ? 0.0 : (value / width).clamp(0.0, 1.0);
        return ClipRect(
          child: Opacity(
            opacity: fraction,
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: fraction,
              child: SizedBox(width: width, child: child),
            ),
          ),
        );
      },
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final hasText = value.text.isNotEmpty;
                final theme = Theme.of(context);
                final radius = BorderRadius.circular(20);
                return TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: widget.onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: hasText
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: '清空',
                            onPressed: _clear,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: radius,
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭搜索',
            onPressed: _close,
          ),
        ],
      ),
    );
  }
}
