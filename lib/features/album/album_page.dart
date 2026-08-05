import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../core/utils/grid_layout.dart';
import '../../widgets/cached_album_art.dart';
import '../../widgets/detail_top_bar.dart';
import '../../widgets/page_toolbar.dart';
import '../../widgets/play_all_button.dart';
import '../../widgets/song_tile.dart';
import '../playlist/song_actions.dart';
import 'album_view_model.dart';

/// 专辑副标题：优先显示 albumArtist；无则显示「多位歌手」。
String _albumSubtitle(Album album) {
  final artist = album.albumArtist?.trim();
  return (artist == null || artist.isEmpty) ? '多位歌手' : artist;
}

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  final _viewModel = AlbumsViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onChanged);
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_viewModel.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final albums = _viewModel.albums;

    return Column(
      children: [
        _buildAppBar(albums.length),
        const Divider(height: 1),
        if (albums.isEmpty)
          _buildEmptyState(theme)
        else
          Expanded(child: _buildGrid(theme, albums)),
      ],
    );
  }

  Widget _buildAppBar(int count) {
    return PageToolbar(title: '专辑', subtitle: '$count 张');
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.album, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('暂无专辑', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '导入音乐文件夹后会自动按专辑归类',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(ThemeData theme, List<Album> albums) {
    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.hardEdge,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        gridDelegate: const SliverGridDelegateWithClampedExtent(
          maxCrossAxisExtent: 200,
          minCrossAxisCount: 2,
          maxCrossAxisCount: 8,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.76,
        ),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return _AlbumCard(
            album: album,
            theme: theme,
            onTap: () => _openAlbumDetail(context, album),
          );
        },
      ),
    );
  }

  void _openAlbumDetail(BuildContext context, Album album) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AlbumDetailPage(album: album)));
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  final ThemeData theme;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art：弹性填满剩余高度，保证下方文字在任何格子宽下不被裁切
            Expanded(
              child: CachedAlbumArt(
                albumArtFilePath: album.albumArtFilePath,
                hasEmbeddedArt: album.albumArtFilePath != null,
                size: double.infinity,
                borderRadius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _albumSubtitle(album),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ─── Album Detail Page ─────────────────────────────────────

class AlbumDetailPage extends StatelessWidget {
  final Album album;

  const AlbumDetailPage({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailTopBar(title: album.name),
      body: _AlbumDetailContent(album: album),
    );
  }
}

class _AlbumDetailContent extends StatefulWidget {
  final Album album;

  const _AlbumDetailContent({required this.album});

  @override
  State<_AlbumDetailContent> createState() => _AlbumDetailContentState();
}

class _AlbumDetailContentState extends State<_AlbumDetailContent> {
  List<Song> _songs = [];

  /// 平铺的行结构：多碟时含 `Disc N` 标题行，单碟时全是歌曲行。
  List<_AlbumRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await ServiceLocator.songRepo.getSongsByAlbum(
      widget.album.id,
    );
    if (mounted) {
      setState(() {
        _songs = songs;
        _rows = _buildRows(songs);
        _loading = false;
      });
    }
  }

  /// 是否多碟专辑（出现 >1 个不同的碟号）。
  bool _hasMultipleDiscs(List<Song> songs) =>
      songs.map((s) => s.discNumber ?? 1).toSet().length > 1;

  /// 按碟分组生成平铺行：多碟时在每组前插入 `Disc N` 标题行。
  List<_AlbumRow> _buildRows(List<Song> songs) {
    if (!_hasMultipleDiscs(songs)) {
      return [for (var i = 0; i < songs.length; i++) _AlbumRow.song(i)];
    }
    final indicesByDisc = <int, List<int>>{};
    for (var i = 0; i < songs.length; i++) {
      final disc = songs[i].discNumber ?? 1;
      indicesByDisc.putIfAbsent(disc, () => []).add(i);
    }
    final discs = indicesByDisc.keys.toList()..sort();
    final rows = <_AlbumRow>[];
    for (final disc in discs) {
      rows.add(_AlbumRow.header(disc));
      rows.addAll([for (final i in indicesByDisc[disc]!) _AlbumRow.song(i)]);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = ServiceLocator.player;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        return Column(
          children: [
            // Album header（底部 Material 阴影分隔列表区）
            Material(
              color: theme.colorScheme.surface,
              elevation: 3,
              child: _buildHeader(theme),
            ),
            // Song list
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                clipBehavior: Clip.hardEdge,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    if (row.isHeader) {
                      return _DiscHeader(disc: row.disc!);
                    }
                    final song = _songs[row.songIndex];
                    final isCurrent = song.id == player.currentSong?.id;
                    return SongTile(
                      song: song,
                      isCurrentSong: isCurrent,
                      onTap: () => ServiceLocator.player.playFromList(
                        _songs,
                        startIndex: row.songIndex,
                      ),
                      leading: SizedBox(
                        width: 36,
                        child: Text(
                          song.trackNumber?.toString() ?? '',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      menuBuilder: (song) => songMenuItems(song),
                      onMenuSelected: (song, value) async {
                        await handleSongMenuAction(context, song, value);
                        await _load();
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 140,
              height: 140,
              child: CachedAlbumArt(
                albumArtFilePath: widget.album.albumArtFilePath,
                hasEmbeddedArt: widget.album.albumArtFilePath != null,
                size: 140,
                borderRadius: 12,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.album.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _albumSubtitle(widget.album),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_songs.length} 首歌曲',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                // 椭圆形「播放全部」文本按钮，位于信息文本下方
                PlayAllButton(
                  onPlayAll: () =>
                      ServiceLocator.player.playFromList(_songs, startIndex: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 专辑详情列表中的一行：`Disc N` 标题行或歌曲行。
class _AlbumRow {
  final int? disc;
  final int songIndex;

  const _AlbumRow.header(this.disc) : songIndex = -1;
  const _AlbumRow.song(this.songIndex) : disc = null;

  bool get isHeader => disc != null;
}

/// 多碟专辑的分碟标题行。
class _DiscHeader extends StatelessWidget {
  final int disc;

  const _DiscHeader({required this.disc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
      child: Text(
        'Disc $disc',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
