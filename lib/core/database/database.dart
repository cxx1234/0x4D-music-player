import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'song_sort_order.dart';
import 'tables/albums.dart';
import 'tables/artists.dart';
import 'tables/playlist_songs.dart';
import 'tables/playlists.dart';
import 'tables/songs.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Songs, Albums, Artists, Playlists, PlaylistSongs])
class FlutterMusicDatabase extends _$FlutterMusicDatabase {
  FlutterMusicDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from == 1) {
          await m.addColumn(songs, songs.isAvailable);
        }
        if (from <= 2) {
          await m.createTable(artists);
          await m.createTable(albums);
          await m.addColumn(songs, songs.artistId);
          await m.addColumn(songs, songs.albumId);
        }
        if (from <= 3) {
          await m.addColumn(songs, songs.titleSortKey);
          await m.addColumn(albums, albums.nameSortKey);
          await m.addColumn(artists, artists.nameSortKey);
          await m.createTable(playlists);
          await m.createTable(playlistSongs);
        }
      },
    );
  }

  static Future<FlutterMusicDatabase> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'music_library.db'));
    return FlutterMusicDatabase(NativeDatabase(dbFile, logStatements: true));
  }

  // ─── CRUD ───────────────────────────────────────────────

  Future<List<Song>> getAllSongs() =>
      (select(songs)..orderBy([
            (t) => OrderingTerm.asc(t.titleSortKey, nulls: NullsOrder.last),
          ]))
          .get();

  Stream<List<Song>> watchAllSongs() =>
      (select(songs)..orderBy([
            (t) => OrderingTerm.asc(t.titleSortKey, nulls: NullsOrder.last),
          ]))
          .watch();

  Future<Song?> getSongById(int id) =>
      (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertSong(SongsCompanion entry) => into(songs).insert(entry);

  Future<int> insertSongOnConflictReplace(SongsCompanion entry) =>
      into(songs).insertOnConflictUpdate(entry);

  Future<int> deleteSong(Song song) => delete(songs).delete(song);

  Future<List<Song>> searchSongs(String query) {
    final pattern = '%$query%';
    return (select(songs)..where(
          (t) =>
              t.title.like(pattern) |
              t.artist.like(pattern) |
              t.album.like(pattern),
        ))
        .get();
  }

  Future<List<Song>> getSongsByFolder(String folderPath) {
    final pattern = '$folderPath%';
    return (select(songs)..where((t) => t.filePath.like(pattern))).get();
  }

  Future<Song?> getSongByFilePath(String filePath) => (select(
    songs,
  )..where((t) => t.filePath.equals(filePath))).getSingleOrNull();

  Future<int> getSongCount() async {
    final result = await customSelect('SELECT COUNT(*) FROM songs').getSingle();
    return result.read<int>('COUNT(*)');
  }

  Future<int> toggleFavorite(int id) {
    return transaction(() async {
      final song = await getSongById(id);
      if (song == null) return 0;
      final newValue = song.isFavorite == 1 ? 0 : 1;
      return (update(songs)..where((t) => t.id.equals(id))).write(
        SongsCompanion(isFavorite: Value(newValue)),
      );
    });
  }

  Future<int> incrementPlayCount(int id) {
    return transaction(() async {
      final song = await getSongById(id);
      if (song == null) return 0;
      return (update(songs)..where((t) => t.id.equals(id))).write(
        SongsCompanion(playCount: Value(song.playCount + 1)),
      );
    });
  }

  // ─── File state sync ────────────────────────────────────

  Future<List<String>> getAllFilePaths() async {
    return (select(
      songs,
    )..where((t) => t.isAvailable.equals(1))).map((s) => s.filePath).get();
  }

  Future<List<String>> getFolderFilePaths(String folderPath) async {
    final pattern = '$folderPath%';
    return (select(songs)
          ..where((t) => t.filePath.like(pattern) & t.isAvailable.equals(1)))
        .map((s) => s.filePath)
        .get();
  }

  Future<int> markAsUnavailable(List<String> filePaths) async {
    return (update(songs)..where((t) => t.filePath.isIn(filePaths))).write(
      SongsCompanion(isAvailable: const Value(0)),
    );
  }

  Future<int> markAsAvailable(String filePath) async {
    return (update(songs)..where((t) => t.filePath.equals(filePath))).write(
      SongsCompanion(isAvailable: const Value(1)),
    );
  }

  Future<int> deleteFolderSongs(String folderPath) async {
    final pattern = '$folderPath%';
    return (delete(songs)..where((t) => t.filePath.like(pattern))).go();
  }

  Future<List<Song>> getUnavailableSongs() {
    return (select(songs)..where((t) => t.isAvailable.equals(0))).get();
  }

  Future<List<Song>> getAvailableSongs({
    SongSortOrder order = SongSortOrder.title,
  }) {
    return (select(songs)
          ..where((t) => t.isAvailable.equals(1))
          ..orderBy(_songOrdering(order)))
        .get();
  }

  // ─── Album queries ──────────────────────────────────────

  Future<List<Album>> getAllAlbums() =>
      (select(albums)..orderBy([
            (t) => OrderingTerm.asc(t.nameSortKey, nulls: NullsOrder.last),
            (t) => OrderingTerm.asc(t.albumArtist),
          ]))
          .get();

  Stream<List<Album>> watchAllAlbums() =>
      (select(albums)..orderBy([
            (t) => OrderingTerm.asc(t.nameSortKey, nulls: NullsOrder.last),
            (t) => OrderingTerm.asc(t.albumArtist),
          ]))
          .watch();

  Future<Album?> getAlbumById(int id) =>
      (select(albums)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Album?> getAlbumByNameAndArtist(String name, int artistId) =>
      (select(albums)
            ..where((t) => t.name.equals(name) & t.artistId.equals(artistId)))
          .getSingleOrNull();

  Future<int> insertAlbum(AlbumsCompanion entry) => into(albums).insert(entry);

  Future<int> updateAlbum(AlbumsCompanion entry, int id) =>
      (update(albums)..where((t) => t.id.equals(id))).write(entry);

  Future<List<Song>> getSongsByAlbum(int albumId) =>
      (select(songs)
            ..where((t) => t.albumId.equals(albumId))
            ..orderBy(_songTrackOrdering()))
          .get();

  Stream<List<Song>> watchSongsByAlbum(int albumId) =>
      (select(songs)
            ..where((t) => t.albumId.equals(albumId))
            ..orderBy(_songTrackOrdering()))
          .watch();

  // ─── Artist queries ─────────────────────────────────────

  Future<List<Artist>> getAllArtists() =>
      (select(artists)..orderBy([
            (t) => OrderingTerm.asc(t.nameSortKey, nulls: NullsOrder.last),
          ]))
          .get();

  Stream<List<Artist>> watchAllArtists() =>
      (select(artists)..orderBy([
            (t) => OrderingTerm.asc(t.nameSortKey, nulls: NullsOrder.last),
          ]))
          .watch();

  Future<Artist?> getArtistById(int id) =>
      (select(artists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Artist?> getArtistByName(String name) =>
      (select(artists)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<int> insertArtist(ArtistsCompanion entry) =>
      into(artists).insert(entry);

  Future<int> updateArtist(ArtistsCompanion entry, int id) =>
      (update(artists)..where((t) => t.id.equals(id))).write(entry);

  Future<List<Song>> getSongsByArtist(int artistId) =>
      (select(songs)
            ..where((t) => t.artistId.equals(artistId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.album),
              ..._songTrackOrdering(),
            ]))
          .get();

  Stream<List<Song>> watchSongsByArtist(int artistId) =>
      (select(songs)
            ..where((t) => t.artistId.equals(artistId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.album),
              ..._songTrackOrdering(),
            ]))
          .watch();

  Future<List<Album>> getAlbumsByArtist(int artistId) =>
      (select(albums)
            ..where((t) => t.artistId.equals(artistId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.year),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .get();

  // ─── Playlist queries ──────────────────────────────────

  Future<List<Playlist>> getAllPlaylists() =>
      (select(playlists)..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
          .get();

  Stream<List<Playlist>> watchAllPlaylists() =>
      (select(playlists)..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
          .watch();

  Future<Playlist?> getPlaylistById(int id) =>
      (select(playlists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertPlaylist(PlaylistsCompanion entry) =>
      into(playlists).insert(entry);

  Future<bool> updatePlaylist(PlaylistsCompanion entry, int id) async =>
      (await (update(playlists)..where((t) => t.id.equals(id))).write(entry)) >
      0;

  Future<void> deletePlaylist(int id) {
    return transaction(() async {
      await (delete(playlistSongs)..where((t) => t.playlistId.equals(id))).go();
      await (delete(playlists)..where((t) => t.id.equals(id))).go();
    });
  }

  /// 播放列表内的歌曲（按 position 排序，过滤不可用文件）。
  Future<List<Song>> getSongsInPlaylist(int playlistId, {int? limit}) {
    final query =
        select(songs).join([
            innerJoin(playlistSongs, playlistSongs.songId.equalsExp(songs.id)),
          ])
          ..where(
            playlistSongs.playlistId.equals(playlistId) &
                songs.isAvailable.equals(1),
          )
          ..orderBy([OrderingTerm.asc(playlistSongs.position)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.map((row) => row.readTable(songs)).get();
  }

  /// 把 [songId] 加入 [playlistId]。若已存在则忽略（不允许重复）。
  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    final nextPos = await _nextPosition(playlistId);
    await into(playlistSongs).insert(
      PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        position: nextPos,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// 批量添加歌曲，跳过已存在的；返回实际新增数量。
  Future<int> addSongsToPlaylist(int playlistId, List<int> songIds) {
    return transaction(() async {
      var count = 0;
      var pos = await _nextPosition(playlistId);
      for (final songId in songIds) {
        if (await _playlistHasSong(playlistId, songId)) continue;
        await into(playlistSongs).insert(
          PlaylistSongsCompanion.insert(
            playlistId: playlistId,
            songId: songId,
            position: pos++,
          ),
        );
        count++;
      }
      return count;
    });
  }

  /// 从播放列表移除歌曲，并重排剩余 position。
  Future<void> removeSongFromPlaylist(int playlistId, int songId) {
    return transaction(() async {
      await (delete(playlistSongs)..where(
            (t) => t.playlistId.equals(playlistId) & t.songId.equals(songId),
          ))
          .go();
      await _renumberPositions(playlistId);
    });
  }

  /// 移动播放列表内歌曲 [oldIndex] → [newIndex]。
  Future<void> moveSongInPlaylist(int playlistId, int oldIndex, int newIndex) {
    return transaction(() async {
      final rows =
          await (select(playlistSongs)
                ..where((t) => t.playlistId.equals(playlistId))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      if (oldIndex < 0 || oldIndex >= rows.length) return;
      if (newIndex < 0 || newIndex > rows.length) return;
      final item = rows.removeAt(oldIndex);
      rows.insert(newIndex, item);
      await _writePositions(rows);
    });
  }

  /// 我的收藏：isFavorite=1 的可用歌曲（按标题排序键）。
  Future<List<Song>> getFavoriteSongs() =>
      (select(songs)
            ..where((t) => t.isFavorite.equals(1) & t.isAvailable.equals(1))
            ..orderBy([
              (t) => OrderingTerm.asc(t.titleSortKey, nulls: NullsOrder.last),
            ]))
          .get();

  Future<int> getFavoriteCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) FROM songs WHERE is_favorite = 1 AND is_available = 1',
    ).getSingle();
    return result.read<int>('COUNT(*)');
  }

  /// 每个播放列表的可用歌曲数。
  Future<Map<int, int>> getPlaylistSongCounts() async {
    final rows = await customSelect(
      'SELECT ps.playlist_id AS pid, COUNT(*) AS c '
      'FROM playlist_songs ps '
      'JOIN songs s ON s.id = ps.song_id '
      'WHERE s.is_available = 1 '
      'GROUP BY ps.playlist_id',
    ).get();
    return {for (final r in rows) r.read<int>('pid'): r.read<int>('c')};
  }

  // ─── Sort key backfill ─────────────────────────────────

  Future<List<Song>> getSongsWithNullSortKey() =>
      (select(songs)..where((t) => t.titleSortKey.isNull())).get();

  Future<void> updateSongSortKey(int id, String key) =>
      (update(songs)..where((t) => t.id.equals(id))).write(
        SongsCompanion(titleSortKey: Value(key)),
      );

  Future<List<Album>> getAlbumsWithNullSortKey() =>
      (select(albums)..where((t) => t.nameSortKey.isNull())).get();

  Future<void> updateAlbumSortKey(int id, String key) =>
      (update(albums)..where((t) => t.id.equals(id))).write(
        AlbumsCompanion(nameSortKey: Value(key)),
      );

  Future<List<Artist>> getArtistsWithNullSortKey() =>
      (select(artists)..where((t) => t.nameSortKey.isNull())).get();

  Future<void> updateArtistSortKey(int id, String key) =>
      (update(artists)..where((t) => t.id.equals(id))).write(
        ArtistsCompanion(nameSortKey: Value(key)),
      );

  // ─── Helpers ───────────────────────────────────────────

  List<OrderingTerm Function($SongsTable)> _songTrackOrdering() => [
    (t) => OrderingTerm.asc(t.discNumber),
    (t) => OrderingTerm.asc(t.trackNumber),
    (t) => OrderingTerm.asc(t.titleSortKey, nulls: NullsOrder.last),
  ];

  List<OrderingTerm Function($SongsTable)> _songOrdering(SongSortOrder order) {
    switch (order) {
      case SongSortOrder.title:
        return [
          (t) => OrderingTerm.asc(t.titleSortKey, nulls: NullsOrder.last),
        ];
      case SongSortOrder.dateAdded:
        return [(t) => OrderingTerm.desc(t.dateAdded)];
      case SongSortOrder.playCount:
        return [(t) => OrderingTerm.desc(t.playCount)];
      case SongSortOrder.year:
        return [(t) => OrderingTerm.desc(t.year)];
    }
  }

  Future<int> _nextPosition(int playlistId) async {
    final result = await customSelect(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next '
      'FROM playlist_songs WHERE playlist_id = ?',
      variables: [Variable(playlistId)],
    ).getSingle();
    return result.read<int>('next');
  }

  Future<bool> _playlistHasSong(int playlistId, int songId) async {
    final row =
        await (select(playlistSongs)
              ..where(
                (t) =>
                    t.playlistId.equals(playlistId) & t.songId.equals(songId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> _renumberPositions(int playlistId) async {
    final rows =
        await (select(playlistSongs)
              ..where((t) => t.playlistId.equals(playlistId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    await _writePositions(rows);
  }

  Future<void> _writePositions(List<PlaylistSong> rows) async {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].position != i) {
        await (update(playlistSongs)..where((t) => t.id.equals(rows[i].id)))
            .write(PlaylistSongsCompanion(position: Value(i)));
      }
    }
  }
}
