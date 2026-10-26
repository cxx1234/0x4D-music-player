import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/motion.dart';
import '../core/database/database.dart';
import '../l10n/l10n.dart';
import 'cached_album_art.dart';
import 'text_link.dart';

/// 纵排封面占内容宽度的比例。
const double kSongInfoCoverFactor = 0.8;

/// 纵排封面的最小尺寸（沿用原来的 380）：低于该尺寸改用横排。
///
/// 纵排所需的最低内容高度 = 本值 + [kSongInfoVerticalTextHeight]（548）。
const double kSongInfoMinCover = 380;

/// 横排封面占内容宽度的比例。
const double kSongInfoHorizontalCoverFactor = 0.4;

/// 横排封面下限（极矮窗口仍保留可辨识尺寸，其余交给外层滚动）。
const double kSongInfoMinHorizontalCover = 120;

/// 迷你条封面尺寸。
const double kSongInfoCompactCover = 48;

/// 纵排封面下方文本区的估算高度：
/// 32（间距）+ 64（标题最多 2 行）+ 4 + 48（操作行）+ 4 + 16（元信息）。
const double kSongInfoVerticalTextHeight = 168;

/// 信息卡形态。
enum SongInfoCardForm { vertical, horizontal, compact }

/// 信息卡布局解析结果：形态 + 封面尺寸（逻辑像素，已取整）。
@immutable
class SongInfoCardLayout {
  final SongInfoCardForm form;
  final double coverSize;

  const SongInfoCardLayout({required this.form, required this.coverSize});
}

/// 解析信息卡形态与封面尺寸（卡片与播放页共用的唯一出处）。
///
/// [contentWidth] / [contentHeight] 是卡片可用的内容区（已扣除页面内边距）。
/// - 纵排：高度充足时取原来的尺寸（`max(宽度 × 0.8, 380)`，不设上限）；
///   高度不足时从该尺寸向下收缩，但不再低于 [kSongInfoMinCover] —— 低于它就
///   改用横排（因此纵排至少需要 `380 + 168` 的内容高度）。
/// - 横排：封面同样受内容高度钳制，极矮时保底 [kSongInfoMinHorizontalCover]。
SongInfoCardLayout resolveSongInfoCardLayout({
  required double contentWidth,
  required double contentHeight,
  bool compact = false,
}) {
  if (compact) {
    return const SongInfoCardLayout(
      form: SongInfoCardForm.compact,
      coverSize: kSongInfoCompactCover,
    );
  }

  final widthDriven = math
      .min(
        contentWidth,
        math.max(contentWidth * kSongInfoCoverFactor, kSongInfoMinCover),
      )
      .floorToDouble();
  final verticalCover = math
      .min(widthDriven, contentHeight - kSongInfoVerticalTextHeight)
      .floorToDouble();
  if (verticalCover >= kSongInfoMinCover) {
    return SongInfoCardLayout(
      form: SongInfoCardForm.vertical,
      coverSize: verticalCover,
    );
  }

  final horizontalWidth = math.min(
    contentWidth,
    math.max(
      contentWidth * kSongInfoHorizontalCoverFactor,
      kSongInfoMinHorizontalCover,
    ),
  );
  return SongInfoCardLayout(
    form: SongInfoCardForm.horizontal,
    coverSize: math
        .min(
          horizontalWidth,
          math.max(contentHeight, kSongInfoMinHorizontalCover),
        )
        .floorToDouble(),
  );
}

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
/// 点击歌手/专辑、封面与 like/more 的行为由外部通过回调注入（本组件不反向依赖
/// features/）。封面尺寸由 [resolveSongInfoCardLayout] 统一解析，页面可通过
/// [coverSize] 注入己算好的结果。
class SongInfoCard extends StatelessWidget {
  final Song song;
  final ThemeData theme;
  final bool isNarrow;
  final bool compact;

  /// 外部解析出的封面尺寸（逻辑像素）；为空时组件按自身宽度回退。
  final double? coverSize;

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
    this.coverSize,
    required this.onLike,
    required this.onOpenArtist,
    required this.onOpenAlbum,
    required this.menuBuilder,
    required this.onMenuSelected,
  });

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

  bool get _canOpenAlbum =>
      song.albumId != null || (song.album?.trim().isNotEmpty ?? false);

  Widget _buildCover(double size) {
    final radius = compact ? 8.0 : 12.0;
    final art = CachedAlbumArt(
      albumArtFilePath: song.albumArtFilePath,
      hasEmbeddedArt: song.hasEmbeddedArt == 1,
      size: size,
      borderRadius: radius,
    );
    if (!_canOpenAlbum) return art;
    return _HoverableCover(radius: radius, onTap: onOpenAlbum, child: art);
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
  Widget _buildActions(BuildContext context) {
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
          tooltip: liked ? context.l10n.playerUnlike : context.l10n.playerLike,
          onPressed: onLike,
        ),
        PopupMenuButton<String>(
          popUpAnimationStyle: kPopupMenuAnimationStyle,
          icon: Icon(
            Icons.more_vert,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          tooltip: context.l10n.commonMore,
          itemBuilder: (_) => menuBuilder(song),
          onSelected: (v) => onMenuSelected(song, v),
        ),
      ],
    );
  }

  /// 窄/迷你共用：封面左 + 信息右 + 动作最右（垂直居中）。
  ///
  /// 窄版封面占内容宽 [kSongInfoHorizontalCoverFactor]（40%），迷你条固定 48；
  /// 页面注入 [coverSize] 时以注入值为准（已含高度钳制）。
  Widget _buildHorizontal(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cover = compact
            ? kSongInfoCompactCover
            : (coverSize ??
                  math
                      .min(
                        constraints.maxWidth,
                        math.max(
                          constraints.maxWidth * kSongInfoHorizontalCoverFactor,
                          kSongInfoMinHorizontalCover,
                        ),
                      )
                      .floorToDouble());
        return Row(
          children: [
            _buildCover(cover),
            SizedBox(width: compact ? 12 : 20),
            Expanded(child: _buildInfoColumn(context)),
          ],
        );
      },
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
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
        if (!compact) ...[
          if (_metaText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _metaText,
              style: _metaStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          _buildActions(context),
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
          child: _buildHorizontal(context),
        ),
      );
    }
    if (isNarrow) {
      return _buildHorizontal(context);
    }

    // 宽版纵排：封面与下方文本同宽，整体居中；尺寸由统一解析函数给出
    // （宽度主导、受高度钳制并封顶），页面未注入时按卡片宽度回退。
    return LayoutBuilder(
      builder: (context, constraints) {
        final cover =
            coverSize ??
            resolveSongInfoCardLayout(
              contentWidth: constraints.maxWidth,
              contentHeight: double.infinity,
            ).coverSize;
        return Center(
          child: SizedBox(
            width: cover,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCover(cover),
                const SizedBox(height: 32),
                Text(
                  song.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: _buildArtistAlbum()),
                    const SizedBox(width: 8),
                    _buildActions(context),
                  ],
                ),
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

/// 封面悬停/点击反馈：封面是不透明的图片，InkWell 的水波会被盖住，
/// 这里用轻微放大提示「可点开专辑」（叠色在亮色封面上不够明显）。
const double _kCoverHoverScale = 1.03;

const Duration _kCoverHoverDuration = Duration(milliseconds: 160);

class _HoverableCover extends StatefulWidget {
  const _HoverableCover({
    required this.radius,
    required this.onTap,
    required this.child,
  });

  final double radius;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_HoverableCover> createState() => _HoverableCoverState();
}

class _HoverableCoverState extends State<_HoverableCover> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    return InkWell(
      borderRadius: radius,
      onTap: widget.onTap,
      onHover: (hovering) {
        if (_hovering == hovering) return;
        setState(() => _hovering = hovering);
      },
      child: AnimatedScale(
        scale: _hovering ? _kCoverHoverScale : 1,
        duration: _kCoverHoverDuration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
