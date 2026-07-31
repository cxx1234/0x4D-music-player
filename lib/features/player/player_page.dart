import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/player_service.dart';
import '../../widgets/cached_album_art.dart';
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

              // ── Right panel: lyrics / queue toggle ──────
              Expanded(
                flex: 6,
                child: _RightPanel(viewModel: _viewModel, theme: theme),
              ),
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
          _AlbumArt(song: song),
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

// ─── Right panel: lyrics / queue toggle ──────────────────────

class _RightPanel extends StatefulWidget {
  final PlayerViewModel viewModel;
  final ThemeData theme;

  const _RightPanel({required this.viewModel, required this.theme});

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  bool _showQueue = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toggle ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TabButton(
                label: '歌词',
                selected: !_showQueue,
                onTap: () => setState(() => _showQueue = false),
              ),
              const SizedBox(width: 4),
              _TabButton(
                label: '播放列表',
                selected: _showQueue,
                onTap: () => setState(() => _showQueue = true),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Content ─────────────────────────────────────
        Expanded(
          child: _showQueue
              ? _QueueView(viewModel: widget.viewModel, theme: widget.theme)
              : _LyricsTab(theme: widget.theme),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Lyrics tab placeholder ──────────────────────────────────

class _LyricsTab extends StatelessWidget {
  final ThemeData theme;

  const _LyricsTab({required this.theme});

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

// ─── Queue view ──────────────────────────────────────────────

class _QueueView extends StatefulWidget {
  final PlayerViewModel viewModel;
  final ThemeData theme;

  const _QueueView({required this.viewModel, required this.theme});

  @override
  State<_QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<_QueueView> {
  bool _deleteMode = false;
  bool _reorderMode = false;
  final Set<int> _selectedIndices = {};

  PlayerViewModel get vm => widget.viewModel;
  ThemeData get theme => widget.theme;

  String _formatDuration(int? ms) {
    if (ms == null) return '';
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  void _toggleDeleteMode() {
    setState(() {
      _deleteMode = !_deleteMode;
      if (!_deleteMode) {
        _selectedIndices.clear();
      }
      _reorderMode = false;
    });
  }

  void _toggleReorderMode() {
    setState(() {
      _reorderMode = !_reorderMode;
      if (_reorderMode) {
        _deleteMode = false;
        _selectedIndices.clear();
      }
    });
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空播放列表'),
        content: const Text('确定要清空当前播放列表吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await vm.clearQueue();
    }
  }

  Future<void> _deleteSelected() async {
    // Sort descending so indices stay valid after removal
    final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      await vm.removeFromQueue(i);
    }
    setState(() {
      _selectedIndices.clear();
      _deleteMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final queue = vm.queue;
    if (queue.isEmpty) {
      return Center(
        child: Text(
          '播放列表为空',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(queue.length),
        const Divider(height: 1),
        Expanded(
          child: Material(
            type: MaterialType.transparency,
            clipBehavior: Clip.hardEdge,
            child: _reorderMode
                ? _buildReorderableList(queue)
                : _buildList(queue),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text(
            '共 $count 首',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (_deleteMode) ...[
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '取消',
              onPressed: _toggleDeleteMode,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.delete_rounded,
                size: 20,
                color: _selectedIndices.isNotEmpty
                    ? theme.colorScheme.error
                    : null,
              ),
              tooltip: '删除选中 (${_selectedIndices.length})',
              onPressed: _selectedIndices.isNotEmpty ? _deleteSelected : null,
            ),
          ] else if (_reorderMode) ...[
            IconButton(
              icon: const Icon(Icons.check, size: 20),
              tooltip: '完成排序',
              onPressed: _toggleReorderMode,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
              tooltip: '清空列表',
              onPressed: _confirmClear,
            ),
            IconButton(
              icon: const Icon(Icons.checklist_rounded, size: 20),
              tooltip: '选择删除',
              onPressed: _toggleDeleteMode,
            ),
            IconButton(
              icon: const Icon(Icons.reorder_rounded, size: 20),
              tooltip: '手动排序',
              onPressed: _toggleReorderMode,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(List<Song> queue) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final song = queue[index];
        final isCurrent = index == vm.currentIndex;
        return _buildListTile(song, index, isCurrent);
      },
    );
  }

  Widget _buildReorderableList(List<Song> queue) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      buildDefaultDragHandles: false,
      itemCount: queue.length,
      onReorderItem: (oldIndex, newIndex) {
        vm.moveInQueue(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final song = queue[index];
        final isCurrent = index == vm.currentIndex;
        return _buildListTile(
          song,
          index,
          isCurrent,
          key: ValueKey(song.filePath),
        );
      },
    );
  }

  Widget _buildListTile(Song song, int index, bool isCurrent, {Key? key}) {
    return ListTile(
      key: key,
      selected: isCurrent,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      leading: _deleteMode
          ? Checkbox(
              value: _selectedIndices.contains(index),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedIndices.add(index);
                  } else {
                    _selectedIndices.remove(index);
                  }
                });
              },
            )
          : _reorderMode
          ? ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle, size: 20),
            )
          : (isCurrent
                ? Icon(
                    Icons.play_arrow_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  )
                : SizedBox(
                    width: 24,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : null,
          color: isCurrent ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: song.artist != null
          ? Text(
              song.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: song.durationMs != null
          ? Text(
              _formatDuration(song.durationMs),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      onTap: _deleteMode
          ? () {
              setState(() {
                if (_selectedIndices.contains(index)) {
                  _selectedIndices.remove(index);
                } else {
                  _selectedIndices.add(index);
                }
              });
            }
          : (isCurrent ? null : () => vm.jumpTo(index)),
    );
  }
}
