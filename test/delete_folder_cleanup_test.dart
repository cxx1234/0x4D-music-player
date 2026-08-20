import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/song_repository.dart';
import 'package:txvziwm/models/scanned_song.dart';

/// 验证移除文件夹后的孤儿数据清理：
/// 被删歌曲对应的专辑/歌手，以及指向已删歌曲的播放列表引用，都应一并清除；
/// 其他文件夹仍在使用的专辑/歌手不受影响。
void main() {
  late AppDatabase db;
  late SongRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SongRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  ScannedSong song({
    required String filePath,
    required String title,
    required String artist,
    required String album,
  }) {
    return ScannedSong(
      filePath: filePath,
      fileName: filePath.split('/').last,
      fileSize: 1000,
      title: title,
      artist: artist,
      album: album,
      mimeType: 'audio/mpeg',
    );
  }

  test('移除文件夹后：孤儿专辑/歌手/播放列表引用一并清除，其他文件夹不受影响', () async {
    // ── 两个文件夹的歌曲：/music 将被移除 ──
    await repo.insertOrUpdateFromScan([
      song(filePath: '/music/1.mp3', title: 'S1', artist: '歌手甲', album: '专辑A'),
      song(filePath: '/music/2.mp3', title: 'S2', artist: '歌手甲', album: '专辑B'),
      song(filePath: '/other/3.mp3', title: 'S3', artist: '歌手乙', album: '专辑C'),
    ]);

    expect((await db.getAllAlbums()).length, 3);
    expect((await db.getAllArtists()).length, 2);

    // ── 建播放列表，把 /music 下的歌都加进去 ──
    final now = DateTime.now().millisecondsSinceEpoch;
    final playlistId = await db.insertPlaylist(
      PlaylistsCompanion.insert(name: '测试列表', createdAt: now, updatedAt: now),
    );
    final musicSongs = (await db.getAllSongs())
        .where((s) => s.filePath.startsWith('/music'))
        .toList();
    await db.addSongsToPlaylist(
      playlistId,
      musicSongs.map((s) => s.id).toList(),
    );
    expect((await db.getSongsInPlaylist(playlistId)).length, 2);

    // ── 移除 /music 文件夹 ──
    final deleted = await repo.removeFolder('/music');
    expect(deleted, 2);

    // 歌曲：/music 的没了，/other 的还在
    final remaining = await db.getAllSongs();
    expect(remaining.length, 1);
    expect(remaining.single.filePath, '/other/3.mp3');

    // 播放列表引用被清掉，列表本身保留
    expect(await db.getSongsInPlaylist(playlistId), isEmpty);
    expect((await db.getAllPlaylists()).length, 1);

    // 专辑：A/B 孤儿被删，C 保留
    final albums = await db.getAllAlbums();
    expect(albums.map((a) => a.name), ['专辑C']);

    // 歌手：甲孤儿被删，乙保留
    final artists = await db.getAllArtists();
    expect(artists.map((a) => a.name), ['歌手乙']);
  });

  test('清空最后一个文件夹后：所有专辑/歌手都被清理', () async {
    await repo.insertOrUpdateFromScan([
      song(filePath: '/only/1.mp3', title: 'S1', artist: '歌手甲', album: '专辑A'),
      song(filePath: '/only/2.mp3', title: 'S2', artist: '歌手甲', album: '专辑A'),
    ]);

    await repo.removeFolder('/only');

    expect(await db.getAllSongs(), isEmpty);
    expect(await db.getAllAlbums(), isEmpty);
    expect(await db.getAllArtists(), isEmpty);
  });
}
