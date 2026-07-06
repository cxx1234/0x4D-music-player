import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/player_service.dart';
import 'player_view_model.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _viewModel = PlayerViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('正在播放'), centerTitle: true),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final song = _viewModel.currentSong;

          // ── Empty state ────────────────────────────────
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

          // ── Active playback — left / right split ───────
          return Row(
            children: [
              // ── Left panel: cover + info + controls ────
              Expanded(
                flex: 4,
                child: _LeftPanel(
                  viewModel: _viewModel,
                  song: song,
                  theme: theme,
                ),
              ),

              const VerticalDivider(width: 1),

              // ── Right panel: lyrics placeholder ────────
              Expanded(flex: 6, child: _LyricsPlaceholder(theme: theme)),
            ],
          );
        },
      ),
    );
  }
}

// ─── Left panel ──────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final PlayerViewModel viewModel;
  final Song song;
  final ThemeData theme;

  const _LeftPanel({
    required this.viewModel,
    required this.song,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Album art ──────────────────────────────────
          _AlbumArt(song: song, theme: theme),
          const SizedBox(height: 32),

          // ── Song info ──────────────────────────────────
          _SongInfo(song: song, theme: theme),
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
  final ThemeData theme;

  const _AlbumArt({required this.song, required this.theme});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace placeholder with actual album art once cover extraction is implemented.
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.music_note_rounded,
          size: 100,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

// ─── Song info ───────────────────────────────────────────────

class _SongInfo extends StatelessWidget {
  final Song song;
  final ThemeData theme;

  const _SongInfo({required this.song, required this.theme});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (song.artist != null) song.artist!,
      if (song.album != null) song.album!,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          song.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

// ─── Lyrics placeholder (right panel) ────────────────────────

class _LyricsPlaceholder extends StatelessWidget {
  final ThemeData theme;

  const _LyricsPlaceholder({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lyrics_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无歌词',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
