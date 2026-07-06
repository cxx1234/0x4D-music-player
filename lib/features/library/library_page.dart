import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import 'library_view_model.dart';

class LibraryPage extends StatefulWidget {
  final bool isInitialized;

  const LibraryPage({super.key, this.isInitialized = false});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _viewModel = LibraryViewModel();
  List<String> _musicFolders = [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChanged);
    _loadFolders();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isInitialized && !oldWidget.isInitialized) {
      _loadFolders();
    }
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  void _loadFolders() {
    if (!widget.isInitialized) return;
    final folders = ServiceLocator.settings.musicFolders;
    if (mounted) {
      setState(() {
        _musicFolders = folders;
        _ready = true;
      });
    }
    _viewModel.initialize();
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || !mounted) return;

    // Create a macOS security-scoped bookmark so the folder remains
    // accessible after app restarts.
    final bookmark = await ServiceLocator.sandbox.createBookmark(path);
    await ServiceLocator.settings.addMusicFolder(path, bookmark: bookmark);
    setState(() => _musicFolders = ServiceLocator.settings.musicFolders);
    _viewModel.startScan();
  }

  Future<void> _removeFolder(String path) async {
    await _viewModel.removeFolder(path);
    setState(() => _musicFolders = ServiceLocator.settings.musicFolders);
  }

  // ─── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_ready) {
      return _buildLoadingState(theme);
    }

    return Column(
      children: [
        _buildAppBar(theme),
        if (_viewModel.isScanning) _buildScanProgress(theme),
        if (_viewModel.scanResult != null && !_viewModel.isScanning)
          _buildScanResult(theme),
        const Divider(height: 1),
        if (_musicFolders.isNotEmpty) _buildFolderList(theme),
        if (_musicFolders.isEmpty && !_viewModel.isScanning)
          _buildEmptyState(theme),
        if (_viewModel.songs.isNotEmpty) _buildSongList(theme),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_music, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('你的音乐库', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('你的音乐库', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '导入音乐文件夹以开始使用',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('导入文件夹'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Text('音乐库', style: theme.textTheme.titleLarge),
          const SizedBox(width: 12),
          if (_viewModel.songs.isNotEmpty)
            Text(
              '${_viewModel.songs.length} 首',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const Spacer(),
          if (_musicFolders.isNotEmpty) ...[
            if (!_viewModel.isScanning)
              IconButton(
                onPressed: _viewModel.startScan,
                icon: const Icon(Icons.refresh),
                tooltip: '重新扫描',
              ),
            FilledButton.icon(
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('导入文件夹'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanProgress(ThemeData theme) {
    final progress = _viewModel.scanProgress;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              if (progress != null && progress.phase == 'collecting')
                const Text('正在扫描文件夹...')
              else if (progress != null && progress.phase == 'parsing')
                Text('正在解析元数据 ${progress.processed}/${progress.total}...')
              else
                const Text('正在处理...'),
              const Spacer(),
              if (progress != null && progress.currentFile.isNotEmpty)
                Flexible(
                  child: Text(
                    progress.currentFile,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          if (progress != null && progress.total > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.processed / progress.total),
          ],
        ],
      ),
    );
  }

  Widget _buildScanResult(ThemeData theme) {
    final result = _viewModel.scanResult!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          Icon(
            result.errors > 0 ? Icons.warning_amber : Icons.check_circle,
            size: 16,
            color: result.errors > 0
                ? Colors.orange
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '扫描完成：${result.added > 0 ? '添加 ${result.added} 首' : '无新文件'}'
            '${result.markedMissing > 0 ? '，${result.markedMissing} 首已移除' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList(ThemeData theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 160),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shrinkWrap: true,
        itemCount: _musicFolders.length,
        itemBuilder: (context, index) {
          final folder = _musicFolders[index];
          return Card(
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.folder),
              title: Text(
                folder,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_viewModel.isScanning)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: '重新扫描此文件夹',
                      onPressed: () => _viewModel.rescanFolder(folder),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: '移除',
                    onPressed: () => _removeFolder(folder),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongList(ThemeData theme) {
    final songs = _viewModel.songs;
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final isCurrentSong = song.id == _viewModel.currentSong?.id;
          return _SongTile(
            song: song,
            theme: theme,
            isCurrentSong: isCurrentSong,
            isPlaying: isCurrentSong && _viewModel.isPlaying,
            onTap: () => _viewModel.playSongFromList(index),
          );
        },
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final ThemeData theme;
  final bool isCurrentSong;
  final bool isPlaying;
  final VoidCallback? onTap;

  const _SongTile({
    required this.song,
    required this.theme,
    this.isCurrentSong = false,
    this.isPlaying = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final duration = song.durationMs;
    final durationStr = duration != null
        ? '${(duration / 60000).floor()}:${((duration % 60000) / 1000).round().toString().padLeft(2, '0')}'
        : null;

    final primaryColor = theme.colorScheme.primary;

    return ListTile(
      selected: isCurrentSong,
      selectedTileColor: primaryColor.withValues(alpha: 0.1),
      leading: CircleAvatar(
        backgroundColor: isCurrentSong
            ? primaryColor
            : theme.colorScheme.secondaryContainer,
        child: isPlaying
            ? _AnimatedPlayingIcon(color: theme.colorScheme.onPrimary)
            : Icon(
                isCurrentSong ? Icons.music_note : Icons.music_note,
                color: isCurrentSong
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSecondaryContainer,
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
        ],
      ),
      onTap: onTap,
    );
  }
}

/// A simple animated icon that alternates bar heights to indicate playback.
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
      builder: (context, child) {
        return CustomPaint(
          size: const Size(18, 18),
          painter: _PlayingBarsPainter(
            color: widget.color,
            value: _controller.value,
          ),
        );
      },
    );
  }
}

class _PlayingBarsPainter extends CustomPainter {
  final Color color;
  final double value;

  _PlayingBarsPainter({required this.color, required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    const barCount = 4;
    final barWidth = 3.0;
    const spacing = 3.0;
    final totalWidth = barCount * barWidth + (barCount - 1) * spacing;
    final startX = (size.width - totalWidth) / 2;
    final baseHeight = 6.0;
    final maxHeight = size.height - 2;

    for (var i = 0; i < barCount; i++) {
      final phase = (i / barCount) * 2 * 3.14159;
      final normalizedPhase = (phase + value * 2 * 3.14159) % (2 * 3.14159);
      final height =
          baseHeight +
          (maxHeight - baseHeight) * (0.5 + 0.5 * sin(normalizedPhase));
      final x = startX + i * (barWidth + spacing);
      final y = size.height - height;
      canvas.drawLine(Offset(x, y), Offset(x, size.height - 2), paint);
    }
  }

  @override
  bool shouldRepaint(_PlayingBarsPainter oldDelegate) =>
      oldDelegate.value != value;
}
