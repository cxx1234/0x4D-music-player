import 'package:flutter/material.dart';

import '../core/constants/layout.dart';

/// 详情页顶部栏：返回键 + 左对齐标题 + 可选操作，替代二级页的 M3 AppBar。
/// 作为 Scaffold 的 `appBar:` 槽位使用（实现 [PreferredSizeWidget]，body 无需改动）。
///
/// - 左侧在 macOS 上预留 [PlatformLayoutConfig.detailTopBarLeftInset]（80）
///   让过红绿灯组；其余平台为 0（Windows 不生效）。
/// - 返回键紧凑：图标 18、命中区约 24，仅比红绿灯（~14）略高。
/// - 标题 `titleMedium`（16）左对齐、单行省略。
/// - 「播放全部」等大操作不放这一栏，由页面自行放置。
///
/// 使用：
/// ```dart
/// Scaffold(
///   appBar: DetailTopBar(title: album.name),
///   body: ...,
/// )
/// ```
class DetailTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DetailTopBar({super.key, required this.title, this.actions});

  final String title;

  /// 右侧操作区（预留，暂无页面使用；后续按钮回归时接入）。
  final List<Widget>? actions;

  @override
  Size get preferredSize => Size.fromHeight(layoutConfig.detailTopBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: layoutConfig.detailTopBarLeftInset,
        right: 12,
      ),
      child: SizedBox(
        height: layoutConfig.detailTopBarHeight,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              iconSize: 18,
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: '返回',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            ...?actions,
          ],
        ),
      ),
    );
  }
}
