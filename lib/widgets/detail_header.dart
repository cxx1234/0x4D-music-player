import 'package:flutter/material.dart';

/// 详情页头部：封面块 + 标题 + 副标题 + 信息 + 可选操作。
///
/// 供专辑详情、播放列表详情、我的收藏等「封面 + 文本 + 播放全部」详情块复用。
/// - [cover] 为 140×140 的封面内容，组件负责 `ClipRRect(12)` + `SizedBox(140)` 包裹
///   （传 `CachedAlbumArt` / `PlaylistCover` / 自定义占位容器）。
/// - 自带 `Material(color: surface, elevation: 3)` 阴影，与下方列表区分隔。
/// - [action] 通常放 [PlayAllButton]，位于信息文本下方。
///
/// 使用：
/// ```dart
/// DetailHeader(
///   cover: CachedAlbumArt(size: 140, ...),
///   title: album.name,
///   subtitle: album.artist,
///   info: '${songs.length} 首歌曲',
///   action: PlayAllButton(onPlayAll: _playAll),
/// )
/// ```
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.cover,
    required this.title,
    this.subtitle,
    this.info,
    this.action,
  });

  /// 140×140 封面内容（CachedAlbumArt / PlaylistCover / 占位容器）。
  final Widget cover;

  /// 标题。
  final String title;

  /// 副标题（可选）。
  final String? subtitle;

  /// 信息文本，如「12 首歌曲」。
  final String? info;

  /// 操作区，如 [PlayAllButton]。
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 140, height: 140, child: cover),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (info != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      info!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (action != null) ...[const SizedBox(height: 12), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
