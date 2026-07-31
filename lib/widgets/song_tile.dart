import 'package:flutter/material.dart';

import '../core/database/database.dart';
import 'cached_album_art.dart';

/// 歌曲行组件：封面 + 标题 + 歌手/专辑 + 时长 + 播放态高亮 + 可选"更多"菜单。
///
/// 供音乐库、专辑详情、歌手详情、搜索等页面复用。
class SongTile extends StatelessWidget {
  final Song song;
  final bool isCurrentSong;
  final bool isPlaying;
  final VoidCallback? onTap;

  /// 自定义行首组件；为 null 时显示封面。
  final Widget? leading;

  /// 构建"更多"菜单项；为 null 时不显示菜单。
  final List<PopupMenuEntry<String>> Function(Song song)? menuBuilder;

  /// 菜单项点击回调，参数为菜单 value 与歌曲。
  final void Function(Song song, String value)? onMenuSelected;

  const SongTile({
    super.key,
    required this.song,
    this.isCurrentSong = false,
    this.isPlaying = false,
    this.onTap,
    this.leading,
    this.menuBuilder,
    this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = song.durationMs;
    final durationStr = duration != null
        ? '${(duration / 60000).floor()}:${((duration % 60000) / 1000).round().toString().padLeft(2, '0')}'
        : null;
    final primaryColor = theme.colorScheme.primary;
    final menu = menuBuilder?.call(song);
    final hasMenu = menu != null && menu.isNotEmpty;

    return ListTile(
      selected: isCurrentSong,
      selectedTileColor: primaryColor.withValues(alpha: 0.1),
      leading:
          leading ??
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedAlbumArt(
                    albumArtFilePath: song.albumArtFilePath,
                    hasEmbeddedArt: song.hasEmbeddedArt == 1,
                    size: 44,
                    borderRadius: 6,
                  ),
                ),
                if (isPlaying)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: _AnimatedPlayingIcon(color: Colors.white),
                    ),
                  ),
                if (isCurrentSong && !isPlaying)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.music_note,
                        size: 8,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrentSong ? primaryColor : null,
          fontWeight: isCurrentSong ? FontWeight.bold : null,
        ),
      ),
      subtitle: Row(
        children: [
          if (song.artist != null && song.artist!.isNotEmpty) ...[
            Flexible(
              child: Text(
                song.artist!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: isCurrentSong ? primaryColor : null),
              ),
            ),
            if (song.album != null) const Text(' · '),
          ],
          if (song.album != null)
            Flexible(
              child: Text(
                song.album!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrentSong)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                isPlaying ? Icons.volume_up_rounded : Icons.pause_rounded,
                size: 18,
                color: primaryColor,
              ),
            ),
          if (durationStr != null)
            Text(
              durationStr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isCurrentSong
                    ? primaryColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (hasMenu)
            PopupMenuButton<String>(
              tooltip: '更多',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => onMenuSelected?.call(song, value),
              itemBuilder: (context) => menu,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 播放中的等化器动画图标。
class _AnimatedPlayingIcon extends StatefulWidget {
  final Color color;

  const _AnimatedPlayingIcon({required this.color});

  @override
  State<_AnimatedPlayingIcon> createState() => _AnimatedPlayingIconState();
}

class _AnimatedPlayingIconState extends State<_AnimatedPlayingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        return SizedBox(
          width: 18,
          height: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(3, (i) {
              final h = 4 + value * 10 * (i % 2 == 0 ? 1 : 0.6);
              return Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
