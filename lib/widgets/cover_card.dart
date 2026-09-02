import 'package:flutter/material.dart';

import 'card_surface.dart';

/// 封面卡片：封面（弹性填满）+ 标题 + 副标题 + 可选右下角操作。
///
/// 供专辑 Grid、播放列表 Grid 等封面网格复用。
/// - 封面区使用 [Expanded] 弹性填满剩余高度，保证下方文字在任何格子宽下不被裁切。
/// - 底部文本块（标题 + 副标题）在左；可选 [trailing]（如三点菜单）位于文本区
///   右上角、与标题顶部对齐。
/// - [onLongPress] 可选；菜单按钮放在 [trailing] 内，点击不会触发 [onTap]。
///
/// 使用：
/// ```dart
/// CoverCard(
///   cover: CachedAlbumArt(size: double.infinity, ...),
///   title: album.name,
///   subtitle: album.artist,
///   onTap: () => _openDetail(album),
/// )
/// ```
class CoverCard extends StatelessWidget {
  const CoverCard({
    super.key,
    required this.cover,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.onLongPress,
  });

  /// 封面内容，通常传 `CachedAlbumArt(size: double.infinity)` 或 `PlaylistCover`。
  final Widget cover;

  /// 标题。
  final String title;

  /// 副标题。
  final String? subtitle;

  /// 文本区右上角的小按钮/菜单，与标题顶部对齐。
  final Widget? trailing;

  /// 点击回调。
  final VoidCallback onTap;

  /// 长按回调（可选）。
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 封面网格卡片自成一合成层：卡内涟漪/悬停等绘制不连带整片可见网格重绘。
    return RepaintBoundary(
      child: CardSurface(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面：弹性填满剩余高度，保证下方文字在任何格子宽下不被裁切
            Expanded(child: cover),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                // 文本块在左，可选操作按钮位于文本区右上角（与标题顶部对齐）
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 4),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
