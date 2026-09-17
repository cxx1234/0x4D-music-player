import 'package:flutter/material.dart';

import 'song_tile.dart';

/// 通用列表行：行首图标 + 标题 + 副标题 + 右侧图标，布局与 [SongTile] 一致
/// （标题 + 副标题组成一个块整体垂直居中，行高固定 72，与各列表
/// `itemExtent: 72` 对齐；无副标题时也保持 72，避免行高不齐）。
///
/// 供歌手、播放列表选择等「非歌曲」实体列表复用。
/// 使用：
/// ```dart
/// ListItemTile(
///   leading: CircleAvatar(child: Text('A')),
///   title: artist.name,
///   subtitle: '10 首歌曲 · 2 张专辑',
///   trailing: const Icon(Icons.chevron_right),
///   onTap: () => _open(artist),
/// )
/// ```
class ListItemTile extends StatelessWidget {
  const ListItemTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  /// 行首图标（头像/图标等）。
  final Widget leading;

  /// 标题。
  final String title;

  /// 副标题（可选），小一号、偏灰。
  final String? subtitle;

  /// 右侧图标（可选）。
  final Widget? trailing;

  /// 点击回调。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListTile(
      // 与 SongTile 一致：文本块整体垂直居中并保持行高。副标题在 title 里，
      // ListTile 一律按「单行」排版，必须显式给 72 才不会在外层 itemExtent: 72
      // 的列表里被挤到上方（详见 SongTile 同名参数注释）。
      minVerticalPadding: 16,
      minTileHeight: SongTile.kRowHeight,
      leading: leading,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ),
        ],
      ),
      subtitle: null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
