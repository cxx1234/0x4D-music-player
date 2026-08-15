import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/layout.dart';
import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';
import '../../widgets/player_controls.dart';
import '../../widgets/text_link.dart';
import '../album/album_page.dart';
import '../artist/artist_page.dart';
import 'lyrics_view.dart';
import 'player_view_model.dart';
import 'queue_view.dart';

class PlayerPage extends StatefulWidget {
  /// 全屏播放页的路由名（用于全局底栏在播放页打开时隐藏）。
  static const String routeName = '/player';

  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

// 宽模式断点：窗口宽度低于此值时隐藏右栏，进入单栏窄模式。
const double _kWideBreakpoint = 760;

// 宽模式下左栏（封面/信息/控制）最小宽度：与当前固定值一致（420）。
const double _kMinLeftPanelWidth = 420;

// 宽模式下左栏最大宽度 = 窗口全宽的 33%。
const double _kLeftPanelFactor = 0.33;

// 封面/进度条共用尺寸上限（防止把控制按钮挤出窗口）。
const double _kMaxCover = 400;

// 封面下方固定内容（信息 + 进度条 + 控制 + 间距）的预留高度，
// 封面高度受限时自动缩小以保证整组不溢出。
const double _kFixedContentReserve = 288;

// A 模式下封面最小尺寸：可用高度不足以容纳「固定内容 + 该尺寸封面」时切到 B。
const double _kAMinCover = 200;

/// 宽模式下左栏宽度：最窄 [_kMinLeftPanelWidth]（与当前固定值一致），
/// 最宽为窗口全宽的 [_kLeftPanelFactor]。
double wideLeftPanelWidth(double windowWidth) {
  return math.max(_kMinLeftPanelWidth, windowWidth * _kLeftPanelFactor);
}

/// 封面/信息/进度条共用尺寸：受内容宽与可用高共同约束，上限 [_kMaxCover]。
///
/// [contentHeight] 为无限（窄模式滚动容器内）时仅按宽度约束；
/// 高度受限时封面缩小以适应，保证控制按钮始终在窗口内。
double playerCoverSize({
  required double contentWidth,
  required double contentHeight,
}) {
  final byHeight = contentHeight.isFinite
      ? contentHeight - _kFixedContentReserve
      : double.infinity;
  final raw = math.min(contentWidth, byHeight);
  return math.min(math.max(raw, 0.0), _kMaxCover);
}

// 窄模式下的可切换标签：播放器 / 歌词 / 播放队列。
enum _NarrowTab { player, lyrics, queue }

class _PlayerPageState extends State<PlayerPage> {
  final _viewModel = PlayerViewModel();

  // 宽模式下右栏显示队列(true)还是歌词(false)。
  bool _showQueue = true;

  // 窄模式当前标签（默认播放器）。
  _NarrowTab _narrowTab = _NarrowTab.player;

  @override
  void initState() {
    super.initState();
    // 打开播放页即对账：把状态对齐到引擎真实值（兜住卡死/热重载失同步）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.resync());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < _kWideBreakpoint;

        return Scaffold(
          appBar: PreferredSize(
            // 总高 = 顶部红绿灯预留（macOS 45）+ 下方 56 控件区；
            // 控件固定在下方区域内，不再随 AppBar 整体垂直居中。
            preferredSize: Size.fromHeight(
              kToolbarHeight + layoutConfig.playerTopBarTopReserve,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部红绿灯预留区（macOS 45，其余 0）。
                SizedBox(height: layoutConfig.playerTopBarTopReserve),
                AppBar(
                  toolbarHeight: kToolbarHeight,
                  leading: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    tooltip: '收起',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.music_note_rounded),
                      const SizedBox(width: 8),
                      // 字号与 DetailTopBar 标题一致（titleMedium）。
                      Text('正在播放', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  centerTitle: false,
                  actions: [
                    if (narrow) ...[
                      // 窄模式：切换歌词/播放队列（选中高亮 + 图标换关闭，再点退出）
                      _NarrowModeTab(
                        icon: Icons.lyrics_rounded,
                        label: '歌词',
                        selected: _narrowTab == _NarrowTab.lyrics,
                        onTap: () => setState(() {
                          _narrowTab = _narrowTab == _NarrowTab.lyrics
                              ? _NarrowTab.player
                              : _NarrowTab.lyrics;
                        }),
                      ),
                      _NarrowModeTab(
                        icon: Icons.queue_music_rounded,
                        label: '播放列表',
                        iconSize: 24,
                        selected: _narrowTab == _NarrowTab.queue,
                        onTap: () => setState(() {
                          _narrowTab = _narrowTab == _NarrowTab.queue
                              ? _NarrowTab.player
                              : _NarrowTab.queue;
                        }),
                      ),
                    ] else ...[
                      // 宽模式：切换右栏内容（选中高亮 + 显示文字）
                      _AppBarTab(
                        icon: Icons.lyrics_rounded,
                        label: '歌词',
                        selected: !_showQueue,
                        onTap: () => setState(() => _showQueue = false),
                      ),
                      _AppBarTab(
                        icon: Icons.queue_music_rounded,
                        label: '播放列表',
                        iconSize: 24,
                        selected: _showQueue,
                        onTap: () => setState(() => _showQueue = true),
                      ),
                    ],
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
          body: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) {
              final song = _viewModel.currentSong;

              // ── Empty state ────────────────────────────
              if (song == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note_rounded,
                        size: 120,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text('未在播放', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        '选择一首歌曲开始播放',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // ── 窄模式：播放器 / 歌词·队列 ─────────────
              if (narrow) {
                // 播放器 ↔ 歌词/队列：整体淡入淡出过渡（方案 A）。
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _narrowTab == _NarrowTab.player
                      ? KeyedSubtree(
                          key: const ValueKey('player'),
                          child: _NarrowPlayer(
                            viewModel: _viewModel,
                            song: song,
                            theme: theme,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('lyricsqueue'),
                          child: _NarrowLyricsQueue(
                            viewModel: _viewModel,
                            song: song,
                            theme: theme,
                            tab: _narrowTab,
                          ),
                        ),
                );
              }

              // ── 宽模式：左栏动态宽（最窄 420，最宽 33%）+ 右栏自适应 ──
              return Row(
                children: [
                  // ── Left panel: cover + info + controls ──
                  SizedBox(
                    width: wideLeftPanelWidth(constraints.maxWidth),
                    child: _LeftPanel(
                      viewModel: _viewModel,
                      song: song,
                      theme: theme,
                      isNarrow: false,
                    ),
                  ),

                  // ── Right panel: lyrics / queue ──────────
                  Expanded(
                    child: _RightPanel(
                      viewModel: _viewModel,
                      theme: theme,
                      showQueue: _showQueue,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Left panel ──────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final PlayerViewModel viewModel;
  final Song song;
  final ThemeData theme;
  final bool isNarrow;

  const _LeftPanel({
    required this.viewModel,
    required this.song,
    required this.theme,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth;

          // 封面尺寸：由内容宽与可用高共同决定（上限 _kMaxCover），
          // 下方信息/进度/控制为固定高度，高度受限时封面自动缩小。
          final coverSize = playerCoverSize(
            contentWidth: contentWidth,
            contentHeight: constraints.maxHeight,
          );

          // 封面 + 播放信息（与封面同宽、左对齐）居中；进度条横贯父容器全宽。
          return Column(
            mainAxisSize: isNarrow ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: isNarrow
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              SizedBox(
                width: coverSize,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AlbumArt(song: song, size: coverSize),
                    const SizedBox(height: 32),
                    // 播放信息在专辑下方，宽度与封面一致。
                    SizedBox(
                      width: coverSize,
                      child: _SongInfo(
                        song: song,
                        theme: theme,
                        isNarrow: isNarrow,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 进度条横贯父容器全宽（不再与封面同宽）。
              _ProgressBar(viewModel: viewModel, theme: theme),
              const SizedBox(height: 16),
              PlayerControls(player: ServiceLocator.player, theme: theme),
            ],
          );
        },
      ),
    );
  }
}

// ─── Album art ───────────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  final Song song;
  final double size;

  const _AlbumArt({required this.song, required this.size});

  @override
  Widget build(BuildContext context) {
    return CachedAlbumArt(
      albumArtFilePath: song.albumArtFilePath,
      hasEmbeddedArt: song.hasEmbeddedArt == 1,
      size: size,
      borderRadius: 12,
    );
  }
}

// ─── Song info ───────────────────────────────────────────────

class _SongInfo extends StatelessWidget {
  final Song song;
  final ThemeData theme;
  final bool isNarrow;

  const _SongInfo({
    required this.song,
    required this.theme,
    required this.isNarrow,
  });

  // 跳歌手详情：优先按 FK 取，其次按名字回退（兜底老数据）。
  Future<void> _openArtist(BuildContext context) async {
    final db = ServiceLocator.database;
    final Artist? artist = song.artistId != null
        ? await db.getArtistById(song.artistId!)
        : null;
    final resolved =
        artist ??
        (song.artist != null ? await db.getArtistByName(song.artist!) : null);
    if (resolved == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArtistDetailPage(artist: resolved)),
    );
  }

  // 跳专辑详情：优先按 FK 取，其次按名字回退（兜底老数据）。
  Future<void> _openAlbum(BuildContext context) async {
    final db = ServiceLocator.database;
    final Album? byId = song.albumId != null
        ? await db.getAlbumById(song.albumId!)
        : null;
    final resolved =
        byId ??
        (song.album != null
            ? song.artistId != null
                  ? await db.getAlbumByNameAndArtist(
                      song.album!,
                      song.artistId!,
                    )
                  : await db.getAlbumByName(song.album!)
            : null);
    if (resolved == null || !context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AlbumDetailPage(album: resolved)));
  }

  @override
  Widget build(BuildContext context) {
    final artist = song.artist?.trim() ?? '';
    final album = song.album?.trim() ?? '';

    // 窄模式（单栏）上下两行都居中；宽模式靠左。
    final textAlign = isNarrow ? TextAlign.center : TextAlign.start;
    final subtitleStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: isNarrow
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          song.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        ),
        if (artist.isNotEmpty || album.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: isNarrow
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              if (artist.isNotEmpty)
                Flexible(
                  fit: FlexFit.loose,
                  child: TextLink(
                    text: artist,
                    style: subtitleStyle,
                    onTap: () => _openArtist(context),
                  ),
                ),
              if (artist.isNotEmpty && album.isNotEmpty)
                Text(' · ', style: subtitleStyle),
              if (album.isNotEmpty)
                Flexible(
                  fit: FlexFit.loose,
                  child: TextLink(
                    text: album,
                    style: subtitleStyle,
                    onTap: () => _openAlbum(context),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Progress bar ────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final PlayerViewModel viewModel;
  final ThemeData theme;

  const _ProgressBar({required this.viewModel, required this.theme});

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final pos = viewModel.position;
    final dur = viewModel.duration;
    final max = dur.inMilliseconds > 0 ? dur : const Duration(seconds: 1);

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: pos.inMilliseconds.toDouble().clamp(
              0,
              max.inMilliseconds.toDouble(),
            ),
            max: max.inMilliseconds.toDouble(),
            onChanged: (v) => viewModel.seek(Duration(milliseconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(pos), style: theme.textTheme.bodySmall),
              Text(_format(dur), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 窄版播放器：按高度切 A（纵向居中）/ B（两栏小播放器）─────

class _NarrowPlayer extends StatelessWidget {
  final PlayerViewModel viewModel;
  final Song song;
  final ThemeData theme;

  const _NarrowPlayer({
    required this.viewModel,
    required this.song,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 高度够容纳「固定内容 + 至少 _kAMinCover 的封面」→ A（纵向居中）；
        // 否则 → B（左右两栏，占用高度更小）。
        final useA =
            constraints.maxHeight >= _kFixedContentReserve + _kAMinCover;
        if (useA) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _LeftPanel(
                viewModel: viewModel,
                song: song,
                theme: theme,
                isNarrow: true,
              ),
            ),
          );
        }
        return _NarrowPlayerB(viewModel: viewModel, song: song, theme: theme);
      },
    );
  }
}

// ─── B 界面：左右两栏（左封面 / 右信息+进度+控制，等宽，控制左对齐）──

class _NarrowPlayerB extends StatelessWidget {
  final PlayerViewModel viewModel;
  final Song song;
  final ThemeData theme;

  const _NarrowPlayerB({
    required this.viewModel,
    required this.song,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 左右 24、上 16、下 32（底部留白略宽，避免贴窗口底边）。
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Row(
        children: [
          // ── 左：封面（按左半区域尺寸，等宽）──
          Expanded(
            child: LayoutBuilder(
              builder: (context, left) {
                final size = math.min(left.maxWidth, left.maxHeight);
                return Center(
                  child: _AlbumArt(song: song, size: size),
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          // ── 右：信息 + 进度 + 控制（左对齐）──
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SongInfo(song: song, theme: theme, isNarrow: false),
                const SizedBox(height: 16),
                _ProgressBar(viewModel: viewModel, theme: theme),
                const SizedBox(height: 12),
                PlayerControls(
                  player: ServiceLocator.player,
                  theme: theme,
                  compact: true,
                  alignment: MainAxisAlignment.start,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 窄版歌词/队列模式：内容块 + 迷你播放器，切换时同步滑动 ──

class _NarrowLyricsQueue extends StatefulWidget {
  final PlayerViewModel viewModel;
  final Song song;
  final ThemeData theme;

  /// 当前标签（lyrics 或 queue）。
  final _NarrowTab tab;

  const _NarrowLyricsQueue({
    required this.viewModel,
    required this.song,
    required this.theme,
    required this.tab,
  });

  @override
  State<_NarrowLyricsQueue> createState() => _NarrowLyricsQueueState();
}

class _NarrowLyricsQueueState extends State<_NarrowLyricsQueue> {
  // 切换方向：+1 右（切到播放列表），-1 左（切到歌词）。
  int _direction = 1;

  @override
  void didUpdateWidget(_NarrowLyricsQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab) {
      _direction = widget.tab == _NarrowTab.queue ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isQueue = widget.tab == _NarrowTab.queue;
    return Column(
      children: [
        // ── 内容块（歌词 ↔ 队列：淡入 + 朝标签方向滑动）──
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(_direction * 0.12, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: isQueue
                ? KeyedSubtree(
                    key: const ValueKey('queue'),
                    child: QueueView(
                      viewModel: widget.viewModel,
                      theme: widget.theme,
                      isNarrow: true,
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('lyrics'),
                    child: LyricsView(theme: widget.theme),
                  ),
          ),
        ),
        // ── 迷你播放器：挂载时缩放浮现（进入歌词/队列），切换 tab 时不动 ──
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            return Transform.scale(
              scale: t,
              alignment: Alignment.bottomCenter,
              child: child,
            );
          },
          child: _MiniPlayer(
            viewModel: widget.viewModel,
            song: widget.song,
            theme: widget.theme,
          ),
        ),
      ],
    );
  }
}

// ─── 底部迷你播放器（窄版歌词/队列模式下常驻）────────────────

class _MiniPlayer extends StatelessWidget {
  final PlayerViewModel viewModel;
  final Song song;
  final ThemeData theme;

  const _MiniPlayer({
    required this.viewModel,
    required this.song,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (song.artist != null && song.artist!.isNotEmpty) song.artist!,
      if (song.album != null && song.album!.isNotEmpty) song.album!,
    ].join(' · ');

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 小封面 + 歌名 / 歌手·专辑 ──
            Row(
              children: [
                CachedAlbumArt(
                  albumArtFilePath: song.albumArtFilePath,
                  hasEmbeddedArt: song.hasEmbeddedArt == 1,
                  size: 48,
                  borderRadius: 6,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
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
              ],
            ),
            const SizedBox(height: 8),
            // ── 进度条（正常宽度）──
            _ProgressBar(viewModel: viewModel, theme: theme),
            const SizedBox(height: 4),
            // ── 控制按钮（compact 缩小、居中）──
            PlayerControls(
              player: ServiceLocator.player,
              theme: theme,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Right panel: lyrics / queue content ─────────────────────

class _RightPanel extends StatefulWidget {
  final PlayerViewModel viewModel;
  final ThemeData theme;
  final bool showQueue;

  const _RightPanel({
    required this.viewModel,
    required this.theme,
    required this.showQueue,
  });

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  // 切换方向：+1 向右（切到播放列表），-1 向左（切到歌词）。
  int _direction = 1;

  @override
  void didUpdateWidget(_RightPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showQueue != oldWidget.showQueue) {
      // 内容朝所点标签方向移动：播放列表（右）→ +1，歌词（左）→ -1。
      _direction = widget.showQueue ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Content（队列 ↔ 歌词：淡入 + 朝标签方向轻滑）────
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(_direction * 0.12, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: widget.showQueue
                ? KeyedSubtree(
                    key: const ValueKey('queue'),
                    child: QueueView(
                      viewModel: widget.viewModel,
                      theme: widget.theme,
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('lyrics'),
                    child: LyricsView(theme: widget.theme),
                  ),
          ),
        ),
      ],
    );
  }
}

// ─── AppBar tab（窄模式：切换歌词/播放队列，选中高亮+关闭图标）─

class _NarrowModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 图标尺寸（播放列表因字形偏小用 22，其余 20）；不影响墨迹/命中区。
  final double iconSize;

  const _NarrowModeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 与宽模式类似：未选中=仅图标+tooltip；选中=高亮 + 图标换「关闭」+ 文本（再点退出）。
    final displayIcon = selected ? Icons.close : icon;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Tooltip(
            message: selected ? '关闭' : label,
            child: SizedBox(
              // 固定墨迹高度（不随图标尺寸变化）。
              height: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      displayIcon,
                      size: iconSize,
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── AppBar tab（宽模式：切换右栏内容）──────────────────────

class _AppBarTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 图标尺寸（播放列表因字形偏小用 22，其余 20）；不影响墨迹/命中区。
  final double iconSize;

  const _AppBarTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: SizedBox(
            // 固定墨迹高度（不随图标尺寸变化）。
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
