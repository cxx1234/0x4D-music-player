import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';

/// 页面刷新的基础：这些 watch 查询必须在写库后自动重新发射。
/// 浏览页/详情页只订阅它们，不再手工重载。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Song> insertSong(
    String title, {
    int? artistId,
    int? albumId,
    int isAvailable = 1,
    String? sortKey,
  }) async {
    final id = await db.insertSong(
      SongsCompanion.insert(
        title: title,
        fileName: '$title.mp3',
        filePath: '/music/$title.mp3',
        dateAdded: DateTime(2024),
        artistId: Value(artistId),
        albumId: Value(albumId),
        isAvailable: Value(isAvailable),
        titleSortKey: Value(sortKey),
      ),
    );
    return (await db.getSongById(id))!;
  }

  Future<int> insertPlaylist(String name) {
    return db.insertPlaylist(
      PlaylistsCompanion.insert(
        name: name,
        createdAt: DateTime(2024).millisecondsSinceEpoch,
        updatedAt: DateTime(2024).millisecondsSinceEpoch,
      ),
    );
  }

  Future<T> next<T>(StreamIterator<T> iterator) async {
    if (!await iterator.moveNext().timeout(const Duration(seconds: 5))) {
      fail('stream closed unexpectedly');
    }
    return iterator.current;
  }

  /// 连续写库可能产生多次发射（drift 按表失效），等到满足 [predicate] 的那次。
  Future<T> nextWhere<T>(
    StreamIterator<T> iterator,
    bool Function(T value) predicate,
  ) async {
    while (true) {
      final value = await next(iterator);
      if (predicate(value)) return value;
    }
  }

  test('watchAvailableSongs 在新增歌曲后重新发射，且过滤不可用行', () async {
    await insertSong('b', sortKey: 'b');
    final iterator = StreamIterator(db.watchAvailableSongs());
    addTearDown(iterator.cancel);

    expect((await next(iterator)).map((s) => s.title), ['b']);

    await insertSong('a', sortKey: 'a');
    expect((await next(iterator)).map((s) => s.title), ['a', 'b']);

    await insertSong('ghost', isAvailable: 0, sortKey: 'c');
    expect((await next(iterator)).map((s) => s.title), ['a', 'b']);
  });

  test('watchSongsByAlbum / watchSongsByArtist 跟随新增歌曲', () async {
    final albums = StreamIterator(db.watchSongsByAlbum(10));
    final artists = StreamIterator(db.watchSongsByArtist(1));
    addTearDown(albums.cancel);
    addTearDown(artists.cancel);

    expect(await next(albums), isEmpty);
    expect(await next(artists), isEmpty);

    await insertSong('x', artistId: 1, albumId: 10);
    expect((await next(albums)).single.title, 'x');
    expect((await next(artists)).single.title, 'x');
  });

  test('watchSongsInPlaylist 跟随加歌 / 移出', () async {
    final song = await insertSong('x');
    final playlistId = await insertPlaylist('p');
    final iterator = StreamIterator(db.watchSongsInPlaylist(playlistId));
    addTearDown(iterator.cancel);

    expect(await next(iterator), isEmpty);

    await db.addSongToPlaylist(playlistId, song.id);
    expect((await next(iterator)).single.id, song.id);

    await db.removeSongFromPlaylist(playlistId, song.id);
    expect(await next(iterator), isEmpty);
  });

  test('watchFavoriteSongs / watchFavoriteCount 跟随收藏切换', () async {
    final song = await insertSong('x');
    final songs = StreamIterator(db.watchFavoriteSongs());
    final count = StreamIterator(db.watchFavoriteCount());
    addTearDown(songs.cancel);
    addTearDown(count.cancel);

    expect(await next(songs), isEmpty);
    expect(await next(count), 0);

    await db.toggleFavorite(song.id);
    expect((await next(songs)).single.id, song.id);
    expect(await next(count), 1);
  });

  test('watchPlaylistSongCounts / watchArtistStats 跟随新歌重新聚合', () async {
    final playlistId = await insertPlaylist('p');
    final counts = StreamIterator(db.watchPlaylistSongCounts());
    final stats = StreamIterator(db.watchArtistStats());
    addTearDown(counts.cancel);
    addTearDown(stats.cancel);

    expect(await next(counts), isEmpty);
    expect(await next(stats), isEmpty);

    final song = await insertSong('x', artistId: 7, albumId: 10);
    await db.addSongToPlaylist(playlistId, song.id);

    final latestCounts = await nextWhere(
      counts,
      (value) => value[playlistId] == 1,
    );
    expect(latestCounts[playlistId], 1);

    final latestStats = await nextWhere(stats, (value) => value[7] != null);
    expect(latestStats[7], (songCount: 1, albumCount: 1));
  });

  test('watchAllAlbums / watchAllArtists 跟随新增行', () async {
    final albums = StreamIterator(db.watchAllAlbums());
    final artists = StreamIterator(db.watchAllArtists());
    addTearDown(albums.cancel);
    addTearDown(artists.cancel);

    expect(await next(albums), isEmpty);
    expect(await next(artists), isEmpty);

    await db.insertArtist(ArtistsCompanion.insert(name: 'Artist'));
    await db.insertAlbum(
      AlbumsCompanion.insert(name: 'Album', nameSortKey: const Value('album')),
    );

    expect((await next(albums)).single.name, 'Album');
    expect((await next(artists)).single.name, 'Artist');
  });
}
