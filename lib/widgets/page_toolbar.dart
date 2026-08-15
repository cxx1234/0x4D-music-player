import 'package:flutter/material.dart';

import '../core/constants/layout.dart';

/// 页面顶部标题工具栏：统一各页（音乐库/专辑/歌手/播放列表/设置）的标题区。
///
/// 结构：总高 [PlatformLayoutConfig.pageToolbarHeight] = 顶部填充
/// [PlatformLayoutConfig.pageToolbarTopInset]
/// + 内容块 [PlatformLayoutConfig.pageToolbarContentHeight]
/// （标题/计数/操作按钮在其中垂直居中）。取值按平台由 [layoutConfig] 决定。
///
/// 使用：
/// ```dart
/// PageToolbar(
///   title: '音乐库',
///   subtitle: '120 首',
///   actions: [IconButton(...), FilledButton.icon(...)],
/// )
/// ```
class PageToolbar extends StatelessWidget {
  const PageToolbar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;

  /// 右侧操作区（排序/刷新/导入/新建等），可为空。
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        top: layoutConfig.pageToolbarTopInset,
        left: 24,
        right: 24,
      ),
      child: SizedBox(
        height: layoutConfig.pageToolbarContentHeight,
        child: Row(
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            if (subtitle case final String subtitleText)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  subtitleText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Spacer(),
            ...?actions,
          ],
        ),
      ),
    );
  }
}
