import 'package:flutter/material.dart';

import '../core/constants/layout.dart';

/// 详情页顶部栏：返回键 + 左对齐标题 + 可选操作，替代二级页的 M3 AppBar。
/// 作为 Scaffold 的 `appBar:` 槽位使用（实现 [PreferredSizeWidget]，body 无需改动）。
///
/// - 左侧在 macOS 上预留 [PlatformLayoutConfig.detailTopBarLeftInset]（95）
///   让过红绿灯组；其余平台为 0（Windows 不生效）。
/// - 返回键与右侧功能按钮通过 [IconButtonTheme] 统一尺寸：图标 22、命中区 36×36。
/// - 标题 `titleMedium`（16）左对齐、单行省略，距左侧按钮约一个按钮宽度。
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
      child: IconButtonTheme(
        // 返回键与右侧功能按钮统一尺寸：图标 22、内边距 8（命中区为 M3 默认 48，天然统一）。
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            iconSize: 20,
            padding: const EdgeInsets.all(8),
          ),
        ),
        child: SizedBox(
          height: layoutConfig.detailTopBarHeight,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              // 文本离左侧按钮约一个按钮（hover 区域）宽度。
              const SizedBox(width: 20),
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
      ),
    );
  }
}
