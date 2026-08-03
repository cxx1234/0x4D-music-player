import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';
import '../../widgets/song_tile.dart';
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
        _buildAppBar(theme, artists.length),
        const Divider(height: 1),
        if (artists.isEmpty)
          _buildEmptyState(theme)
        else
          Expanded(child: _buildList(theme, artists)),
      ],
    );
  }

  Widget _buildAppBar(ThemeData theme, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Text('歌手', style: theme.textTheme.titleLarge),
          const SizedBox(width: 12),
          Text(
            '$count 位',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '$songCount 首歌曲${albumCount > 0 ? ' · $albumCount 张专辑' : ''}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
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
      appBar: AppBar(
        title: Text(artist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play),
            tooltip: '播放全部',
            onPressed: () => _playAll(context),
          ),
        ],
      ),
      body: _ArtistDetailContent(artist: artist),
    );
  }

  void _playAll(BuildContext context) async {
    final songs = await ServiceLocator.songRepo.getSongsByArtist(artist.id);
    if (songs.isNotEmpty) {
      ServiceLocator.player.playFromList(songs, startIndex: 0);
    }
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

    return CustomScrollView(
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
          child: _SectionHeader(title: '歌曲 (${_songs.length})'),
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
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
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
        // Navigate to album detail using the existing AlbumDetailPage
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(album.name)),
              body: _AlbumDetailContent(album: album),
            ),
          ),
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

/// Re-export AlbumDetailContent for use from Artist detail.
/// Imported from the album feature.
class _AlbumDetailContent extends StatefulWidget {
  final Album album;

  const _AlbumDetailContent({required this.album});

  @override
  State<_AlbumDetailContent> createState() => _AlbumDetailContentState();
}

class _AlbumDetailContentState extends State<_AlbumDetailContent> {
  List<Song> _songs = [];
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
        _loading = false;
      });
    }
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: CachedAlbumArt(
                        albumArtFilePath: widget.album.albumArtFilePath,
                        hasEmbeddedArt: widget.album.albumArtFilePath != null,
                        size: 120,
                        borderRadius: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.album.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_songs.length} 首歌曲',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                clipBehavior: Clip.hardEdge,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    final isCurrent = song.id == player.currentSong?.id;
                    return SongTile(
                      song: song,
                      isCurrentSong: isCurrent,
                      onTap: () => ServiceLocator.player.playFromList(
                        _songs,
                        startIndex: index,
                      ),
                      leading: SizedBox(
                        width: 32,
                        child: Text(
                          '${index + 1}',
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
}
