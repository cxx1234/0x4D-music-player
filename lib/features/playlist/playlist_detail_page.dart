import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../core/constants/motion.dart';
import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';
import '../../l10n/l10n.dart';
import '../../widgets/detail_header.dart';
import '../../widgets/detail_top_bar.dart';
import '../../widgets/play_all_button.dart';
import '../../widgets/song_tile.dart';
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
  bool _reorderMode = false;
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

  /// 按名称排序（复用 title_sort_key 拼音键，升序）整理列表：
  /// 重写 position 后重载，排序可随时切回手动拖拽调整。
  Future<void> _sortByName() async {
    if (_songs.length < 2) return;
    // 稳定排序：主键 titleSortKey（拼音，缺失排末尾），相同再按原标题兜底。
    final ordered = [..._songs]
      ..sort((a, b) {
        final ka = a.titleSortKey;
        final kb = b.titleSortKey;
        if (ka == null && kb == null) return a.title.compareTo(b.title);
        if (ka == null) return 1;
        if (kb == null) return -1;
        final c = ka.compareTo(kb);
        return c != 0 ? c : a.title.compareTo(b.title);
      });
    await ServiceLocator.songRepo.reorderSongsInPlaylist(widget.playlist.id, [
      for (final s in ordered) s.id,
    ]);
    if (!mounted) return;
    // 名称排序后退出手动排序模式，列表按新顺序呈现。
    if (_reorderMode) setState(() => _reorderMode = false);
    await _load();
  }

  Future<void> _addSongs() async {
    final added = await showAddSongsSheet(context, widget.playlist.id);
    if (added != null && added > 0) {
      await _load();
    }
  }

  Future<void> _exportM3u() async {
    final l10n = context.l10n;
    final ({Uint8List bytes, int count}) content;
    try {
      content = await buildPlaylistM3u8(widget.playlist.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.playlistExportFailed)));
      return;
    }

    final uri = await FilePicker.saveFile(
      dialogTitle: l10n.playlistExport,
      fileName: '$_name.m3u8',
      bytes: content.bytes,
      type: FileType.custom,
      allowedExtensions: const ['m3u8', 'm3u'],
    );
    if (uri == null || !mounted) return;
    // saveFile 已把 bytes 写入所选位置，uri 非空即成功。
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.playlistExported(content.count))),
    );
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.playlistRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.commonName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.commonSave),
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
        title: Text(context.l10n.playlistDelete),
        content: Text(context.l10n.playlistDeleteConfirm(_name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonDelete),
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

  void _toggleReorderMode() {
    setState(() => _reorderMode = !_reorderMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = ServiceLocator.player;

    return Scaffold(
      appBar: DetailTopBar(
        title: _name,
        actions: [
          IconButton(
            icon: Icon(_reorderMode ? Icons.check : Icons.reorder_rounded),
            tooltip: _reorderMode
                ? context.l10n.playlistDoneSorting
                : context.l10n.playlistManualSort,
            onPressed: _toggleReorderMode,
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: context.l10n.playlistAddSongs,
            onPressed: _addSongs,
          ),
          PopupMenuButton<String>(
            popUpAnimationStyle: kPopupMenuAnimationStyle,
            tooltip: context.l10n.commonMore,
            // 默认 iconTheme.color 是固定纯黑/纯白（M2 遗留），显式指定跟随主题。
            iconColor: theme.colorScheme.onSurfaceVariant,
            onSelected: (value) {
              if (value == 'rename') _rename();
              if (value == 'delete') _delete();
              if (value == 'export') _exportM3u();
              if (value == 'sortByName') _sortByName();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Text(context.l10n.playlistExportM3u),
              ),
              PopupMenuItem(
                value: 'sortByName',
                child: Text(context.l10n.playlistSortByName),
              ),
              PopupMenuItem(
                value: 'rename',
                child: Text(context.l10n.playlistMenuRename),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(context.l10n.commonDelete),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        // uiListenable：切歌/播放态/队列变化均会重建列表高亮。
        listenable: player.uiListenable,
        builder: (context, _) {
          return Column(
            children: [
              // 头部（底部 Material 阴影分隔列表区）
              DetailHeader(
                cover: PlaylistCover(
                  playlistId: widget.playlist.id,
                  size: 140,
                  borderRadius: 12,
                  revision: _songs.length,
                ),
                title: _name,
                info: context.l10n.albumSongCount(_songs.length),
                action: PlayAllButton(
                  onPlayAll: _playAll,
                  enabled: _songs.isNotEmpty,
                ),
              ),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_songs.isEmpty)
                _buildEmptyState(theme)
              else
                Expanded(child: _buildSongListView(theme)),
            ],
          );
        },
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
            Text(
              context.l10n.playlistEmpty,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.playlistEmptyHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 歌曲列表：默认普通列表（显示序号，不可拖拽）；开启排序后为可拖拽列表。
  Widget _buildSongListView(ThemeData theme) {
    final list = _reorderMode
        ? ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            buildDefaultDragHandles: false,
            onReorderItem: _onReorder,
            itemCount: _songs.length,
            itemBuilder: (context, index) => _songRow(theme, index),
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _songs.length,
            itemBuilder: (context, index) => _songRow(theme, index),
          );
    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.hardEdge,
      child: list,
    );
  }

  Widget _songRow(ThemeData theme, int index) {
    final song = _songs[index];
    final isCurrent = song.id == ServiceLocator.player.currentSong?.id;
    return _buildSongRow(theme, song, index, isCurrent);
  }

  Widget _buildSongRow(ThemeData theme, Song song, int index, bool isCurrent) {
    return SongTile(
      key: ValueKey(song.id),
      song: song,
      isCurrentSong: isCurrent,
      isPlaying: isCurrent && ServiceLocator.player.isPlaying,
      // 排序模式下关掉右键：行左槽已经是拖拽把手，再弹菜单只会打架。
      contextMenuEnabled: !_reorderMode,
      onTap: () =>
          ServiceLocator.player.playFromList(_songs, startIndex: index),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 固定宽度槽位：序号与拖拽把手同宽、居中，切换排序模式宽度不跳动。
          // 排序模式下整个槽位都是拖拽命中区。
          if (_reorderMode)
            ReorderableDragStartListener(
              index: index,
              child: SizedBox(
                width: 36,
                height: 32,
                child: Center(
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: 36,
              height: 32,
              child: Center(
                child: Text(
                  '${index + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          // 序号/拖拽把手与封面间距（翻倍，避免贴住封面）
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
      menuBuilder: (song) => [
        PopupMenuItem(value: 'play', child: Text(context.l10n.playerPlay)),
        PopupMenuItem(
          value: 'remove',
          child: Text(context.l10n.playlistRemoveFrom),
        ),
      ],
      onMenuSelected: (song, value) {
        if (value == 'play') {
          ServiceLocator.player.playFromList(_songs, startIndex: index);
        } else if (value == 'remove') {
          _removeSong(song);
        }
      },
    );
  }
}
