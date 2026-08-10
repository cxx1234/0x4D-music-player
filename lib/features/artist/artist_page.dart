import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';
import '../../widgets/detail_top_bar.dart';
import '../../widgets/list_item_tile.dart';
import '../../widgets/page_toolbar.dart';
import '../../widgets/play_all_button.dart';
import '../../widgets/song_tile.dart';
import '../album/album_page.dart';
import '../playlist/song_actions.dart';
import 'artist_view_model.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  final _viewModel = ArtistsViewModel();

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

    final artists = _viewModel.artists;

    return Column(
      children: [
        _buildAppBar(artists.length),
        const Divider(height: 1),
        if (artists.isEmpty)
          _buildEmptyState(theme)
        else
          Expanded(child: _buildList(theme, artists)),
      ],
    );
  }

  Widget _buildAppBar(int count) {
    return PageToolbar(title: '歌手', subtitle: '$count 位');
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('暂无歌手', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '导入音乐文件夹后会自动按歌手归类',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme, List<Artist> artists) {
    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.hardEdge,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final artist = artists[index];
          final albumCount = _viewModel.albumsForArtist(artist).length;
          final songCount = _viewModel.songsForArtist(artist).length;
          return ListItemTile(
            leading: CircleAvatar(
              // 44 直径，与 SongTile 默认封面同宽，保证标题位置一致
              radius: 22,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: artist.name,
            subtitle:
                '$songCount 首歌曲${albumCount > 0 ? ' · $albumCount 张专辑' : ''}',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openArtistDetail(context, artist),
          );
        },
      ),
    );
  }

  void _openArtistDetail(BuildContext context, Artist artist) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ArtistDetailPage(artist: artist)));
  }
}

// ─── Artist Detail Page ────────────────────────────────────

class ArtistDetailPage extends StatelessWidget {
  final Artist artist;

  const ArtistDetailPage({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailTopBar(title: artist.name),
      body: _ArtistDetailContent(artist: artist),
    );
  }
}

class _ArtistDetailContent extends StatefulWidget {
  final Artist artist;

  const _ArtistDetailContent({required this.artist});

  @override
  State<_ArtistDetailContent> createState() => _ArtistDetailContentState();
}

class _ArtistDetailContentState extends State<_ArtistDetailContent> {
  List<Album> _albums = [];
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ServiceLocator.songRepo.getAllAlbums(),
      ServiceLocator.songRepo.getSongsByArtist(widget.artist.id),
    ]);
    final allAlbums = results[0] as List<Album>;
    final songs = results[1] as List<Song>;

    // 专辑按该歌手歌曲的 albumId 派生：合集/多歌手专辑每位参与歌手都能看到。
    final albumById = {for (final a in allAlbums) a.id: a};
    final albumsById = <int, Album>{};
    for (final s in songs) {
      final albumId = s.albumId;
      if (albumId == null) continue;
      final album = albumById[albumId];
      if (album != null) albumsById[albumId] = album;
    }
    final albums = albumsById.values.toList()
      ..sort((a, b) {
        final byYear = (a.year ?? 0).compareTo(b.year ?? 0);
        if (byYear != 0) return byYear;
        return a.name.compareTo(b.name);
      });

    if (mounted) {
      setState(() {
        _albums = albums;
        _songs = songs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // 有界滚动区含 ListTile(SongTile) 交互项，外包透明 Material + Clip.hardEdge
    // 防止墨迹渗入上方标题区（项目约定）。
    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.hardEdge,
      child: CustomScrollView(
        slivers: [
          // Albums section
          if (_albums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(title: '专辑 (${_albums.length})'),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _albums.length,
                  itemBuilder: (context, index) {
                    final album = _albums[index];
                    return _ArtistAlbumCard(album: album);
                  },
                ),
              ),
            ),
          ],

          // Songs section
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: '歌曲 (${_songs.length})',
              trailing: PlayAllButton(
                onPlayAll: () =>
                    ServiceLocator.player.playFromList(_songs, startIndex: 0),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final song = _songs[index];
                final player = ServiceLocator.player;
                final isCurrent = song.id == player.currentSong?.id;
                return SongTile(
                  song: song,
                  isCurrentSong: isCurrent,
                  onTap: () => ServiceLocator.player.playFromList(
                    _songs,
                    startIndex: index,
                  ),
                  menuBuilder: (song) => songMenuItems(song),
                  onMenuSelected: (song, value) async {
                    await handleSongMenuAction(context, song, value);
                    await _load();
                  },
                );
              }, childCount: _songs.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ArtistAlbumCard extends StatelessWidget {
  final Album album;

  const _ArtistAlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        // 跳转正式专辑详情页（DetailTopBar + 分碟 + 播放全部）
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AlbumDetailPage(album: album)),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 150,
                height: 150,
                child: CachedAlbumArt(
                  albumArtFilePath: album.albumArtFilePath,
                  hasEmbeddedArt: album.albumArtFilePath != null,
                  size: 150,
                  borderRadius: 8,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
