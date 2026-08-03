import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/player_service.dart';
import '../../widgets/cached_album_art.dart';
import 'lyrics_page.dart';
import 'lyrics_view.dart';
import 'player_view_model.dart';
import 'queue_page.dart';
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

// 宽模式下左栏固定宽度（播放控制行最小需求 ~384px，留出缓冲）。
const double _kLeftPanelWidth = 420;

class _PlayerPageState extends State<PlayerPage> {
  final _viewModel = PlayerViewModel();

  // 宽模式下右栏显示队列(true)还是歌词(false)。
  bool _showQueue = true;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openLyrics() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LyricsPage()));
  }

  void _openQueue() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QueuePage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < _kWideBreakpoint;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: '收起',
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_note_rounded),
                SizedBox(width: 8),
                Text('正在播放'),
              ],
            ),
            centerTitle: false,
            actions: [
              if (narrow) ...[
                // 窄模式：两个图标跳转全屏页
                IconButton(
                  icon: const Icon(Icons.lyrics_rounded),
                  tooltip: '歌词',
                  onPressed: _openLyrics,
                ),
                IconButton(
                  icon: const Icon(Icons.queue_music_rounded),
                  tooltip: '播放列表',
                  onPressed: _openQueue,
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
                  selected: _showQueue,
                  onTap: () => setState(() => _showQueue = true),
                ),
              ],
              const SizedBox(width: 8),
            ],
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

              // ── 窄模式：单栏（右栏隐藏）───────────────
              if (narrow) {
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _LeftPanel(
                        viewModel: _viewModel,
                        song: song,
                        theme: theme,
                        isNarrow: true,
                      ),
                    ),
                  ),
                );
              }

              // ── 宽模式：左栏固定宽 + 右栏自适应 ────────
              return Row(
                children: [
                  // ── Left panel: cover + info + controls ──
                  SizedBox(
                    width: _kLeftPanelWidth,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Album art ──────────────────────────────────
          _AlbumArt(song: song),
          const SizedBox(height: 32),

          // ── Song info ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: _SongInfo(song: song, theme: theme, isNarrow: isNarrow),
          ),
          const SizedBox(height: 32),

          // ── Progress bar ───────────────────────────────
          _ProgressBar(viewModel: viewModel, theme: theme),
          const SizedBox(height: 24),

          // ── Playback controls ──────────────────────────
          _PlaybackControls(viewModel: viewModel, theme: theme),
        ],
      ),
    );
  }
}

// ─── Album art ───────────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  final Song song;

  const _AlbumArt({required this.song});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
        child: CachedAlbumArt(
          albumArtFilePath: song.albumArtFilePath,
          hasEmbeddedArt: song.hasEmbeddedArt == 1,
          size: 300,
          borderRadius: 12,
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (song.artist != null) song.artist!,
      if (song.album != null) song.album!,
    ].join(' · ');

    // 窄模式（单栏）上下两行都居中；宽模式靠左。
    final textAlign = isNarrow ? TextAlign.center : TextAlign.start;

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
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
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

// ─── Playback controls ───────────────────────────────────────

class _PlaybackControls extends StatelessWidget {
  final PlayerViewModel viewModel;
  final ThemeData theme;

  const _PlaybackControls({required this.viewModel, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Repeat mode
        _IconButton(
          icon: _repeatIcon(viewModel.repeatMode),
          isActive: viewModel.repeatMode != PlayerRepeatMode.off,
          onPressed: viewModel.cycleRepeatMode,
        ),
        const SizedBox(width: 8),

        // Previous
        _IconButton(
          icon: Icons.skip_previous_rounded,
          isActive: false,
          onPressed: viewModel.previous,
        ),
        const SizedBox(width: 8),

        // Play / Pause
        IconButton(
          iconSize: 64,
          onPressed: viewModel.togglePlay,
          icon: Icon(
            viewModel.isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),

        // Next
        _IconButton(
          icon: Icons.skip_next_rounded,
          isActive: false,
          onPressed: viewModel.next,
        ),
        const SizedBox(width: 8),

        // Shuffle
        _IconButton(
          icon: Icons.shuffle_rounded,
          isActive: viewModel.isShuffled,
          onPressed: viewModel.toggleShuffle,
        ),
      ],
    );
  }

  IconData _repeatIcon(PlayerRepeatMode mode) {
    switch (mode) {
      case PlayerRepeatMode.off:
        return Icons.repeat_rounded;
      case PlayerRepeatMode.one:
        return Icons.repeat_one_rounded;
      case PlayerRepeatMode.all:
        return Icons.repeat_rounded;
    }
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onPressed;

  const _IconButton({
    required this.icon,
    required this.isActive,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      iconSize: 32,
      onPressed: onPressed,
      icon: Icon(icon, color: isActive ? theme.colorScheme.primary : null),
    );
  }
}

// ─── Right panel: lyrics / queue content ─────────────────────

class _RightPanel extends StatelessWidget {
  final PlayerViewModel viewModel;
  final ThemeData theme;
  final bool showQueue;

  const _RightPanel({
    required this.viewModel,
    required this.theme,
    required this.showQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Content ─────────────────────────────────────
        Expanded(
          child: showQueue
              ? QueueView(viewModel: viewModel, theme: theme)
              : LyricsView(theme: theme),
        ),
      ],
    );
  }
}

// ─── AppBar tab（宽模式：切换右栏内容）──────────────────────

class _AppBarTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AppBarTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
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
    );
  }
}
