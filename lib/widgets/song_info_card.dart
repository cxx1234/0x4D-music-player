import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/database/database.dart';
import 'cached_album_art.dart';
import 'text_link.dart';

/// 宽版纵排封面占信息卡宽度的比例（随信息卡尺寸变化）。
const double _kCoverFactor = 0.8;

/// 宽版纵排封面最小尺寸（信息卡较窄时封底）。
const double _kMinCover = 380;

/// 窄版横排封面占卡片宽度的比例（信息卡填充中间区域时）。
const double _kNarrowCoverFactor = 0.4;

/// 从文件名扩展名推导文件类型（如 `song.mp3` → `MP3`；无扩展名返回空串）。
String fileTypeOf(Song song) {
  final name = song.fileName;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toUpperCase();
}

/// 歌曲信息卡片（正在播放页的信息模块，宽/窄/迷你三形态共享）。
///
/// - 宽版（[isNarrow]=false）：纵排 —— cover 居中在上，title / 歌手·专辑 / 格式·采样率
///   在左，`like` `more` 在歌手·专辑一行最右（卡片变宽时 left 不动、右侧远离）。
/// - 窄版（[isNarrow]=true）：横排 —— cover 在左、信息在右，`like` `more` 最右垂直居中。
/// - [compact]：迷你条（cover 48），用于窄窗口歌词/队列模式。
///
/// 点击歌手/专辑与 like/more 的行为由外部通过回调注入（本组件不反向依赖 features/）。
class SongInfoCard extends StatelessWidget {
  final Song song;
  final ThemeData theme;
  final bool isNarrow;
  final bool compact;

  final VoidCallback onLike;
  final VoidCallback onOpenArtist;
  final VoidCallback onOpenAlbum;
  final List<PopupMenuEntry<String>> Function(Song song) menuBuilder;
  final void Function(Song song, String value) onMenuSelected;

  const SongInfoCard({
    super.key,
    required this.song,
    required this.theme,
    this.isNarrow = false,
    this.compact = false,
    required this.onLike,
    required this.onOpenArtist,
    required this.onOpenAlbum,
    required this.menuBuilder,
    required this.onMenuSelected,
  });

  double get _coverSize => compact ? 48 : 160;

  TextStyle? get _subtitleStyle => theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );

  /// 格式 | 采样率：颜色更灰、字号更小。
  TextStyle? get _metaStyle => theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
  );

  String get _metaText {
    final parts = <String>[
      if (fileTypeOf(song).isNotEmpty) fileTypeOf(song),
      if (song.sampleRate != null) '${song.sampleRate} Hz',
    ];
    return parts.join(' | ');
  }

  Widget _buildCover({double? size}) {
    final coverSize = size ?? _coverSize;
    return CachedAlbumArt(
      albumArtFilePath: song.albumArtFilePath,
      hasEmbeddedArt: song.hasEmbeddedArt == 1,
      size: coverSize,
      borderRadius: compact ? 8 : 12,
    );
  }

  /// 歌手 · 专辑（可点击，横向排列，短文本自适应/长文本省略）。
  Widget _buildArtistAlbum({TextStyle? style}) {
    final s = style ?? _subtitleStyle;
    final artist = song.artist?.trim() ?? '';
    final album = song.album?.trim() ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (artist.isNotEmpty)
          Flexible(
            fit: FlexFit.loose,
            child: TextLink(text: artist, style: s, onTap: onOpenArtist),
          ),
        if (artist.isNotEmpty && album.isNotEmpty) Text(' · ', style: s),
        if (album.isNotEmpty)
          Flexible(
            fit: FlexFit.loose,
            child: TextLink(text: album, style: s, onTap: onOpenAlbum),
          ),
      ],
    );
  }

  /// like / more 动作区。
  Widget _buildActions() {
    final liked = song.isFavorite == 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            color: liked
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          iconSize: 22,
          tooltip: liked ? '取消喜欢' : '喜欢',
          onPressed: onLike,
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          tooltip: '更多',
          itemBuilder: (_) => menuBuilder(song),
          onSelected: (v) => onMenuSelected(song, v),
        ),
      ],
    );
  }

  /// 窄/迷你共用：封面左 + 信息右 + 动作最右（垂直居中）。
  ///
  /// 窄版（非 compact）封面 = 卡片宽 × [_kNarrowCoverFactor]（30%），
  /// 信息占剩余；迷你条封面固定 48。
  Widget _buildHorizontal() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = compact
            ? 48.0
            : constraints.maxWidth * _kNarrowCoverFactor;
        return Row(
          children: [
            _buildCover(size: coverSize),
            SizedBox(width: compact ? 12 : 20),
            Expanded(child: _buildInfoColumn()),
            const SizedBox(width: 4),
            _buildActions(),
          ],
        );
      },
    );
  }

  Widget _buildInfoColumn() {
    final artist = song.artist?.trim() ?? '';
    final album = song.album?.trim() ?? '';
    // 迷你条（compact）用更小字号；隐藏文件信息。
    final titleStyle = compact
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold);
    final subtitleStyle = compact
        ? theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )
        : _subtitleStyle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          song.title,
          style: titleStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (artist.isNotEmpty || album.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildArtistAlbum(style: subtitleStyle),
        ],
        if (!compact && _metaText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _metaText,
            style: _metaStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // 迷你条：背景与控制区（PlayerBar）一致，加内边距避免贴边。
      return Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildHorizontal(),
        ),
      );
    }
    if (isNarrow) {
      return _buildHorizontal();
    }

    // 宽版纵排：封面与下方文本同宽（coverSize），整体居中；
    // 封面尺寸随信息卡宽度变化（coverSize = max(cardWidth × 0.8, 400)）。
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = math.max(
          constraints.maxWidth * _kCoverFactor,
          _kMinCover,
        );
        return Center(
          child: SizedBox(
            width: coverSize,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCover(size: coverSize),
                const SizedBox(height: 32),
                Text(
                  song.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (song.artist?.trim().isNotEmpty == true ||
                    song.album?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: _buildArtistAlbum()),
                      const SizedBox(width: 8),
                      _buildActions(),
                    ],
                  ),
                ],
                if (_metaText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _metaText,
                    style: _metaStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
