import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/database/song_sort_order.dart';
import '../../core/services/service_locator.dart';
import '../../widgets/page_toolbar.dart';
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
  Timer? _readyTimer;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChanged);
    _loadFolders();
    _scheduleReadyRetry();
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  /// 兜底：ServiceLocator 尚未就绪时轮询等待，就绪后自动加载。
  ///
  /// 不依赖 [didUpdateWidget] —— Flutter 的 `MaterialApp.home` 参数变化
  /// 不会刷新 Navigator 里已存在的初始 route，导致 `isInitialized` 信号
  /// 从未到达本页面，启动后不做任何操作会一直转圈。
  void _scheduleReadyRetry() {
    _readyTimer?.cancel();
    if (widget.isInitialized || ServiceLocator.isReady) return;
    _readyTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (widget.isInitialized || ServiceLocator.isReady) {
        _readyTimer?.cancel();
        _readyTimer = null;
        _loadFolders();
      }
    });
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
    // 初始化完成前等待 didUpdateWidget / 轮询兜底触发；ServiceLocator 已
    // 就绪时即使 isInitialized 信号意外丢失也能立即加载，避免一直转圈。
    if (!widget.isInitialized && !ServiceLocator.isReady) return;
    _readyTimer?.cancel();
    _readyTimer = null;
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
        _buildAppBar(),
        if (ServiceLocator.sandboxRestoreFailures > 0)
          _buildSandboxWarning(theme),
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

  /// macOS 沙箱权限恢复失败的提示横幅 + 重新授权入口。
  Widget _buildSandboxWarning(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 16,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '音乐文件夹访问权限已失效，请重新授权',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: _reauthorizeFolder,
                child: const Text('重新授权'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 重新授权音乐文件夹：重新选择文件夹并刷新 bookmark，随后重扫恢复数据。
  Future<void> _reauthorizeFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || !mounted) return;

    final bookmark = await ServiceLocator.sandbox.createBookmark(path);
    await ServiceLocator.settings.updateMusicFolderBookmark(path, bookmark);
    ServiceLocator.clearSandboxRestoreFailures();
    setState(() => _musicFolders = ServiceLocator.settings.musicFolders);
    _viewModel.startScan();
  }

  Widget _buildAppBar() {
    return PageToolbar(
      title: '音乐库',
      subtitle: _viewModel.songs.isNotEmpty
          ? '${_viewModel.songs.length} 首'
          : null,
      actions: [
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
            '${result.markedMissing > 0 ? '，${result.markedMissing} 首已移除' : ''}'
            '${result.errors > 0 ? '，${result.errors} 处失败' : ''}',
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
