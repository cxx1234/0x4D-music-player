import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/database/song_sort_order.dart';
import '../../core/services/service_locator.dart';
import '../../widgets/song_tile.dart';
import '../playlist/song_actions.dart';
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
          if (_viewModel.songs.isNotEmpty)
            PopupMenuButton<SongSortOrder>(
              tooltip: '排序',
              icon: const Icon(Icons.sort),
              onSelected: _viewModel.setSortOrder,
              itemBuilder: (context) => [
                for (final order in SongSortOrder.values)
                  CheckedPopupMenuItem(
                    value: order,
                    checked: order == _viewModel.sortOrder,
                    child: Text(order.label),
                  ),
              ],
            ),
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
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.hardEdge,
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
      ),
    );
  }

  Widget _buildSongList(ThemeData theme) {
    final songs = _viewModel.songs;
    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.hardEdge,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final isCurrentSong = song.id == _viewModel.currentSong?.id;
            return SongTile(
              song: song,
              isCurrentSong: isCurrentSong,
              isPlaying: isCurrentSong && _viewModel.isPlaying,
              onTap: () => _viewModel.playSongFromList(index),
              menuBuilder: (song) => songMenuItems(song),
              onMenuSelected: (song, value) async {
                await handleSongMenuAction(context, song, value);
                await _viewModel.reloadSongs();
              },
            );
          },
        ),
      ),
    );
  }
}
