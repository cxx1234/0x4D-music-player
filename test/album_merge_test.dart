import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/core/database/database.dart';
import 'package:flutter_music/core/services/song_repository.dart';
import 'package:flutter_music/models/scanned_song.dart';

/// 验证扫描期专辑归并逻辑：同一专辑多歌手 → 只生成一条专辑记录。
void main() {
  late FlutterMusicDatabase db;
  late SongRepository repo;

  setUp(() {
    db = FlutterMusicDatabase(NativeDatabase.memory());
    repo = SongRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  ScannedSong song({
    required String title,
    String? artist,
    String? albumArtist,
    String? album,
  }) {
    return ScannedSong(
      filePath: '/music/$title.mp3',
      fileName: '$title.mp3',
      fileSize: 1000,
      title: title,
      artist: artist,
      albumArtist: albumArtist,
      album: album,
      mimeType: 'audio/mpeg',
    );
  }

  test('同一专辑不同歌手 → 只生成一条专辑记录，歌曲都指向它', () async {
    await repo.insertOrUpdateFromScan([
      song(title: 'A1', artist: '歌手甲', album: '合集X'),
      song(title: 'B1', artist: '歌手乙', album: '合集X'),
      song(title: 'C1', artist: '歌手丙', album: '合集X'),
    ]);

    final albums = await db.getAllAlbums();
    expect(albums.length, 1);
    expect(albums.single.name, '合集X');

    final albumIds = (await db.getAllSongs()).map((s) => s.albumId).toSet();
    expect(albumIds, {albums.single.id});
  });

  test('同一歌手多首歌 → 一条专辑记录', () async {
    await repo.insertOrUpdateFromScan([
      song(title: 'A1', artist: '歌手甲', album: '我的专辑'),
      song(title: 'A2', artist: '歌手甲', album: '我的专辑'),
    ]);

    final albums = await db.getAllAlbums();
    expect(albums.length, 1);
    expect(albums.single.albumArtist, '歌手甲');
  });

  test('多歌手合集 + 统一 albumArtist 标签 → 仍合并为一条', () async {
    await repo.insertOrUpdateFromScan([
      song(title: 'A1', artist: '歌手甲', albumArtist: '群星', album: '精选'),
      song(title: 'B1', artist: '歌手乙', albumArtist: '群星', album: '精选'),
    ]);

    final albums = await db.getAllAlbums();
    expect(albums.length, 1);
    expect(albums.single.albumArtist, '群星');
  });

  test('不同歌手 + 不同 albumArtist 标签的同名专辑 → 不合并', () async {
    await repo.insertOrUpdateFromScan([
      song(title: 'A1', artist: '歌手甲', albumArtist: '甲厂牌', album: '同名辑'),
      song(title: 'B1', artist: '歌手乙', albumArtist: '乙厂牌', album: '同名辑'),
    ]);

    final albums = await db.getAllAlbums();
    expect(albums.length, 2);
  });

  test('getAlbumByName 基础查询', () async {
    await repo.insertOrUpdateFromScan([
      song(title: 'A1', artist: '歌手甲', album: '唯一专辑'),
    ]);

    final album = await db.getAlbumByName('唯一专辑');
    expect(album, isNotNull);
    expect(album!.name, '唯一专辑');
    expect(await db.getAlbumByName('不存在'), isNull);
  });
}
