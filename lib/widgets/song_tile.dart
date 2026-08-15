import 'package:flutter/material.dart';

import '../core/database/database.dart';
import 'cached_album_art.dart';

/// 歌曲行组件：封面 + 标题 + 歌手/专辑 + 时长 + 播放态高亮 + 可选"更多"菜单。
///
/// 供音乐库、专辑详情、歌手详情等页面复用。
class SongTile extends StatelessWidget {
  final Song song;
  final bool isCurrentSong;
  final bool isPlaying;
  final VoidCallback? onTap;

  /// 自定义行首组件；为 null 时显示封面。
  final Widget? leading;

  /// 行首序号/轨号文本；非空时显示内置的固定 36×32 居中槽位（优先于默认封面）。
  final String? leadingText;

  /// 构建"更多"菜单项；为 null 时不显示菜单。
  final List<PopupMenuEntry<String>> Function(Song song)? menuBuilder;

  /// 菜单项点击回调，参数为菜单 value 与歌曲。
  final void Function(Song song, String value)? onMenuSelected;

  /// 是否显示"当前播放"行尾指示图标（音量/暂停）。
  /// 某些列表（如播放队列）用 leading 指示当前项，传 false 可避免重复。
  final bool showCurrentIndicator;

  const SongTile({
    super.key,
    required this.song,
    this.isCurrentSong = false,
    this.isPlaying = false,
    this.onTap,
    this.leading,
    this.leadingText,
    this.menuBuilder,
    this.onMenuSelected,
    this.showCurrentIndicator = true,
  });

  /// 副标题：歌手 · 专辑（有则显示，自动省略）。比标题小一号、偏灰；
  /// 当前播放时整行都使用主题色。
  Widget _buildSubtitle(TextStyle? baseStyle, Color primaryColor) {
    final Color? highlight = isCurrentSong ? primaryColor : null;
    return Row(
      children: [
        if (song.artist != null && song.artist!.isNotEmpty) ...[
          Flexible(
            child: Text(
              song.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseStyle?.copyWith(color: highlight),
            ),
          ),
          if (song.album != null)
            Text(' · ', style: baseStyle?.copyWith(color: highlight)),
        ],
        if (song.album != null)
          Flexible(
            child: Text(
              song.album!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseStyle?.copyWith(color: highlight),
            ),
          ),
      ],
    );
  }

  /// 行首：自定义 [leading] > 内置序号 [leadingText] > 默认封面。
  Widget _buildLeading(ThemeData theme, Color primaryColor) {
    if (leading != null) return leading!;
    if (leadingText != null) {
      // 内置序号/轨号：固定 36×32 居中槽位，各列表序号位置一致
      return SizedBox(
        width: 36,
        height: 32,
        child: Center(
          child: Text(
            leadingText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isCurrentSong
                  ? primaryColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SizedBox(
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
    );
  }

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
    final hasSubtitle =
        (song.artist != null && song.artist!.isNotEmpty) || song.album != null;
    // title 槽位会统一应用标题样式，副标题需显式回退为小一号、偏灰
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListTile(
      selected: isCurrentSong,
      selectedTileColor: primaryColor.withValues(alpha: 0.1),
      minVerticalPadding: 16,
      leading: _buildLeading(theme, primaryColor),
      // 标题 + 副标题组成一个块，整体垂直居中（ListTile 单行模式 titleY 居中）；
      // minVerticalPadding 16 保证双行块行高 ~72（M3 双行规格），文本不再随
      // leading 高度上下偏移。
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrentSong ? primaryColor : null,
              fontWeight: isCurrentSong ? FontWeight.bold : null,
            ),
          ),
          if (hasSubtitle) _buildSubtitle(subtitleStyle, primaryColor),
        ],
      ),
      subtitle: null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCurrentIndicator && isCurrentSong)
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
          if (hasMenu) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: '更多',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => onMenuSelected?.call(song, value),
              itemBuilder: (context) => menu,
            ),
          ],
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
