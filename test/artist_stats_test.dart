import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';

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
      ),
    );
    return (await db.getSongById(id))!;
  }

  test('getArtistStats 按歌手聚合歌曲数与专辑数', () async {
    // 歌手1：3 首可用歌，分属 2 张专辑（a1/a2 同专辑，a3 另一张）
    await insertSong('a1', artistId: 1, albumId: 10);
    await insertSong('a2', artistId: 1, albumId: 10);
    await insertSong('a3', artistId: 1, albumId: 11);
    // 歌手2：2 首可用歌，1 张专辑（另一首无专辑，只计歌曲数）
    await insertSong('b1', artistId: 2, albumId: 20);
    await insertSong('b2', artistId: 2, albumId: null);
    // 无歌手：不计入
    await insertSong('c1', artistId: null, albumId: 30);
    // 歌手1 的不可用歌曲：不计入
    await insertSong('a4', artistId: 1, albumId: 10, isAvailable: 0);

    final stats = await db.getArtistStats();
    expect(stats.length, 2);
    expect(stats[1], (songCount: 3, albumCount: 2));
    expect(stats[2], (songCount: 2, albumCount: 1));
  });
}
