import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';
import 'add_songs_sheet.dart';
import 'playlist_cover.dart';
import 'playlist_io.dart';

/// 播放列表详情页：头部 + 可拖动排序的歌曲列表 + 加歌/重命名/删除。
class PlaylistDetailPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  List<Song> _songs = [];
  bool _loading = true;
  late String _name = widget.playlist.name;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await ServiceLocator.songRepo.getSongsInPlaylist(
      widget.playlist.id,
    );
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _loading = false;
    });
  }

  void _playAll() {
    if (_songs.isNotEmpty) {
      ServiceLocator.player.playFromList(_songs, startIndex: 0);
    }
  }

  Future<void> _addSongs() async {
    final added = await showAddSongsSheet(context, widget.playlist.id);
    if (added != null && added > 0) {
      await _load();
    }
  }

  Future<void> _exportM3u() async {
    final path = await FilePicker.saveFile(
      dialogTitle: '导出播放列表',
      fileName: '$_name.m3u8',
      type: FileType.custom,
      allowedExtensions: const ['m3u8', 'm3u'],
    );
    if (path == null || !mounted) return;
    final count = await exportPlaylistToFile(widget.playlist.id, path);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已导出 $count 首歌曲')));
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名播放列表'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final ok = await ServiceLocator.songRepo.updatePlaylist(
      PlaylistsCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
      widget.playlist.id,
    );
    if (ok && mounted) {
      setState(() => _name = name);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除播放列表'),
        content: Text('确定删除"$_name"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ServiceLocator.songRepo.deletePlaylist(widget.playlist.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _removeSong(Song song) async {
    await ServiceLocator.songRepo.removeSongFromPlaylist(
      widget.playlist.id,
      song.id,
    );
    await _load();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    // onReorderItem 已把 newIndex 调整为移除后的目标位置。
    await ServiceLocator.songRepo.moveSongInPlaylist(
      widget.playlist.id,
      oldIndex,
      newIndex,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = ServiceLocator.player;

    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: '添加歌曲',
            onPressed: _addSongs,
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play),
            tooltip: '播放全部',
            onPressed: _playAll,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') _rename();
              if (value == 'delete') _delete();
              if (value == 'export') _exportM3u();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('导出为 M3U…')),
              PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          return Column(
            children: [
              _buildHeader(theme),
              const Divider(height: 1),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_songs.isEmpty)
                _buildEmptyState(theme)
              else
                Expanded(
                  child: Material(
                    type: MaterialType.transparency,
                    clipBehavior: Clip.hardEdge,
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      buildDefaultDragHandles: false,
                      onReorderItem: _onReorder,
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        final isCurrent = song.id == player.currentSong?.id;
                        return _buildSongRow(theme, song, index, isCurrent);
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          PlaylistCover(
            playlistId: widget.playlist.id,
            size: 140,
            borderRadius: 12,
            revision: _songs.length,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_songs.length} 首歌曲',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
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
              Icons.playlist_add,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('播放列表为空', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '点击右上角"添加歌曲"按钮加入歌曲',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongRow(ThemeData theme, Song song, int index, bool isCurrent) {
    final primaryColor = theme.colorScheme.primary;
    return ListTile(
      key: ValueKey(song.id),
      selected: isCurrent,
      selectedTileColor: primaryColor.withValues(alpha: 0.1),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedAlbumArt(
                albumArtFilePath: song.albumArtFilePath,
                hasEmbeddedArt: song.hasEmbeddedArt == 1,
                size: 40,
                borderRadius: 6,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? primaryColor : null,
          fontWeight: isCurrent ? FontWeight.bold : null,
        ),
      ),
      subtitle: song.artist != null
          ? Text(song.artist!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: PopupMenuButton<String>(
        tooltip: '更多',
        onSelected: (value) {
          if (value == 'play') {
            ServiceLocator.player.playFromList(_songs, startIndex: index);
          } else if (value == 'remove') {
            _removeSong(song);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'play', child: Text('播放')),
          PopupMenuItem(value: 'remove', child: Text('从播放列表移除')),
        ],
      ),
      onTap: () =>
          ServiceLocator.player.playFromList(_songs, startIndex: index),
    );
  }
}
