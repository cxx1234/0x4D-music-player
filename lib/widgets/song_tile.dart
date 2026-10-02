import 'package:flutter/material.dart';

import '../core/constants/motion.dart';
import '../core/database/database.dart';
import 'cached_album_art.dart';

/// 歌曲行组件：封面 + 标题 + 歌手/专辑 + 时长 + 播放态高亮 + 可选"更多"菜单。
///
/// 供音乐库、专辑详情、歌手详情等页面复用。
class SongTile extends StatefulWidget {
  /// 固定行高；调用方列表用 `ListView(itemExtent: 72)`、`IndexScrollbar`
  /// 也用 72 定位，两处必须一致。
  static const double kRowHeight = 72;

  final Song song;

  /// 是否为当前播放歌曲：决定整行高亮（底色 + 主色标题/副标题/时长 + 行首指示）。
  final bool isCurrentSong;

  /// 是否正在播放当前歌曲；**仅在 [isCurrentSong] 为 true 时生效**
  /// （封面播放中遮罩 + 行尾音量图标）。各调用方都需传，否则同一首歌在不同
  /// 页面的高亮表现会不一致。
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

  /// 鼠标右键（次级点击）回调，参数是行自己的 context 与歌曲。
  ///
  /// 行内**有**三点菜单（[menuBuilder] 非空）时不会触发 —— 那种行右键等价于点
  /// 三点，直接调 `showButtonMenu()`（位置与动画天然一致），所以音乐库 / 专辑
  /// 详情 / 歌手详情 / 我的收藏 / 播放列表详情这五个调用点无需任何改动。
  ///
  /// 锚点由调用方用 `context_menu.dart` 的 `overlayRectOf` + `rowMenuSlot` 算，
  /// 与三点按钮同位置。
  final void Function(BuildContext rowContext, Song song)? onSecondaryTap;

  /// 右键是否响应，默认 true。
  ///
  /// 排序/删除这类「行上已经另有拖拽/勾选手势」的模式里传 false：右键菜单会和
  /// 那些手势打架（有内层三点菜单时也同样被关掉）。
  final bool contextMenuEnabled;

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
    this.onSecondaryTap,
    this.contextMenuEnabled = true,
    this.showCurrentIndicator = true,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  /// 行尾三点菜单的句柄。
  ///
  /// 右键要用它调到**同一个** `PopupMenuButton`，位置才会和点三点一模一样；
  /// 自己算个矩形再 `showMenu` 是另一份定位逻辑，迟早会走样。
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();

  /// 只收次级点击（右键 / Control+点击 / 双指轻点）。主键点击仍由 ListTile 自己
  /// 的 InkWell 处理 —— 那个 InkWell 只注册了主键手势，两者不抢。
  void _onSecondaryTap() {
    if (!widget.contextMenuEnabled) return;
    if (widget.menuBuilder != null) {
      _menuKey.currentState?.showButtonMenu();
      return;
    }
    widget.onSecondaryTap?.call(context, widget.song);
  }

  /// 副标题：歌手 · 专辑（有则显示，自动省略）。比标题小一号、偏灰；
  /// 当前播放时整行都使用主题色。
  Widget _buildSubtitle(TextStyle? baseStyle, Color primaryColor) {
    final song = widget.song;
    final Color? highlight = widget.isCurrentSong ? primaryColor : null;
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
    final leading = widget.leading;
    final leadingText = widget.leadingText;
    final isCurrentSong = widget.isCurrentSong;
    final isPlaying = widget.isPlaying;
    final song = widget.song;
    // 局部别名可被提升类型，所以这里不用 `!`。
    if (leading != null) return leading;
    if (leadingText != null) {
      // 内置序号/轨号：固定 36×32 居中槽位，各列表序号位置一致
      return SizedBox(
        width: 36,
        height: 32,
        child: Center(
          child: Text(
            leadingText,
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
          // 播放中遮罩只在「当前歌曲 + 正在播放」时出现：非当前曲即使调用方
          // 误传 isPlaying 也不会点亮，保证各列表高亮语义一致。
          if (isCurrentSong && isPlaying)
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
    // 字段别名：本类从 StatelessWidget 改成 StatefulWidget 后，下面的排版代码
    // 保持原样可读（避免满屏 widget.xxx 干扰真正改动的 diff）。
    final song = widget.song;
    final isCurrentSong = widget.isCurrentSong;
    final isPlaying = widget.isPlaying;
    final menuBuilder = widget.menuBuilder;
    final onMenuSelected = widget.onMenuSelected;
    final showCurrentIndicator = widget.showCurrentIndicator;
    final duration = song.durationMs;
    final durationStr = duration != null
        ? '${(duration / 60000).floor()}:${((duration % 60000) / 1000).round().toString().padLeft(2, '0')}'
        : null;
    final primaryColor = theme.colorScheme.primary;
    // 只判断「有没有菜单回调」：菜单内容依赖实时播放状态（随机开关/是否已在
    // 队列），已在 itemBuilder 内按需构建；若在这里真构建一次，会为每行每次
    // 重建都跑 songMenuItems（内含 O(n) 队列查）。
    final hasMenu = menuBuilder != null;
    final hasSubtitle =
        (song.artist != null && song.artist!.isNotEmpty) || song.album != null;
    // title 槽位会统一应用标题样式，副标题需显式回退为小一号、偏灰
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final row = ListTile(
      selected: isCurrentSong,
      selectedTileColor: primaryColor.withValues(alpha: 0.1),
      minVerticalPadding: 16,
      // 必须显式给 72：SongTile 把副标题放进 title 里，对 ListTile 而言永远是
      // 「单行」模式，它会按 1 行默认高 56 计算 titleY/leadingY 再居中；而外层
      // 列表用 itemExtent: 72 把行高紧约束成 72，多出的 8px 全落在底部 →
      // 无歌手/专辑（没有副标题）的行整体偏上 8px。固定 72 后单行/双行
      // 排版尺寸都与 itemExtent 一致，内容与封面都居中。
      minTileHeight: SongTile.kRowHeight,
      leading: _buildLeading(theme, primaryColor),
      // 标题 + 副标题组成一个块，整体垂直居中（ListTile 单行模式 titleY 居中）。
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
              // 与右侧时长文本拉开间距（原 8 太贴近，视觉上像连在一起）
              padding: const EdgeInsets.only(right: 12),
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
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              key: _menuKey,
              popUpAnimationStyle: kPopupMenuAnimationStyle,
              tooltip: '更多',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => onMenuSelected?.call(song, value),
              // 菜单项依赖实时播放状态（随机开关/是否已在队列），必须在每次
              // 打开时重新求值，不能复用 build 时捕获的 [menu]——列表页只
              // 订阅切歌/播放态，切循环/随机模式不会触发本行重建。
              itemBuilder: (context) => menuBuilder(song),
            ),
          ],
        ],
      ),
      onTap: widget.onTap,
    );

    // 既没有三点菜单、也没人要右键（或右键被关掉）的行不包这层手势。
    if (!hasMenu &&
        (widget.onSecondaryTap == null || !widget.contextMenuEnabled)) {
      return row;
    }
    return GestureDetector(onSecondaryTap: _onSecondaryTap, child: row);
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
