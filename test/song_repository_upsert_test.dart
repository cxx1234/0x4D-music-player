import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/song_repository.dart';
import 'package:txvziwm/models/scanned_song.dart';

/// 回归测试：`insertOrUpdateFromScan` 必须能对"已存在路径"的歌曲执行更新
/// （upsert），而不是因 file_path 唯一约束冲突回滚整个事务。
///
/// 背景：drift 的 `insertOnConflictUpdate` 默认只以主键 `id` 做冲突检测，
/// 而歌曲插入不提供自增 `id`，导致重扫已存在歌曲时触发 file_path 唯一约束
/// 错误 → 事务回滚 → 数据库从不更新（改标签/重扫无效的根因）。
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
    required String title,
    String? artist,
    String? album,
    String path = '/music/same.mp3',
    int? lastModifiedMs,
  }) {
    return ScannedSong(
      filePath: path,
      fileName: path.split('/').last,
      fileSize: 1000,
      lastModifiedMs: lastModifiedMs,
      title: title,
      artist: artist,
      album: album,
      mimeType: 'audio/mpeg',
    );
  }

  test('同路径重扫 → 更新而非新增：行数不变、元数据被覆盖', () async {
    await repo.insertOrUpdateFromScan([
      song(title: 'Old Title', artist: '旧歌手', album: '旧专辑'),
    ]);

    await repo.insertOrUpdateFromScan([
      song(title: 'New Title', artist: '新歌手', album: '新专辑'),
    ]);

    final songs = await db.getAllSongs();
    expect(songs, hasLength(1));
    expect(songs.single.title, 'New Title');
    expect(songs.single.artist, '新歌手');
    expect(songs.single.album, '新专辑');
  });

  test('重扫更新时保留用户数据（收藏/播放次数不被覆盖）', () async {
    await repo.insertOrUpdateFromScan([song(title: 'T1')]);
    final first = (await db.getAllSongs()).single;
    await db.toggleFavorite(first.id);

    await repo.insertOrUpdateFromScan([song(title: 'T2')]);

    final songs = await db.getAllSongs();
    expect(songs, hasLength(1));
    expect(songs.single.title, 'T2');
    expect(songs.single.isFavorite, 1);
  });

  test('更新已存在歌曲时保留原 dateAdded（重扫不重置最近添加）', () async {
    await repo.insertOrUpdateFromScan([song(title: 'T1')]);
    final first = (await db.getAllSongs()).single;
    final original = first.dateAdded;

    // 模拟稍后重扫:即使时间前进,dateAdded 也应保持不变。
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await repo.insertOrUpdateFromScan([song(title: 'T2')]);

    final songs = await db.getAllSongs();
    expect(songs, hasLength(1));
    expect(songs.single.dateAdded, original);
  });

  test('lastModifiedMs 随扫描写入（变化检测用）', () async {
    await repo.insertOrUpdateFromScan([
      song(title: 'A', path: '/music/m.mp3', lastModifiedMs: 123456),
    ]);

    final s = (await db.getAllSongs()).single;
    expect(s.lastModifiedMs, 123456);
  });

  test('cleanupOrphans 清除无歌曲引用的专辑与歌手', () async {
    await repo.insertOrUpdateFromScan([
      song(title: 'A', artist: '甲', album: '专辑X', path: '/music/a.mp3'),
      song(title: 'B', artist: '乙', album: '专辑Y', path: '/music/b.mp3'),
    ]);

    // 删除第一首歌后清理:专辑X 与歌手甲 应消失,专辑Y 保留。
    final a = (await db.getAllSongs()).firstWhere((s) => s.title == 'A');
    await db.deleteSong(a);
    await repo.cleanupOrphans();

    final albums = (await db.getAllAlbums()).map((x) => x.name).toList();
    expect(albums, ['专辑Y']);
    final artists = (await db.getAllArtists()).map((x) => x.name).toList();
    expect(artists, ['乙']);
  });

  test('不同路径各自独立插入', () async {
    await repo.insertOrUpdateFromScan([song(title: 'A', path: '/music/a.mp3')]);
    await repo.insertOrUpdateFromScan([song(title: 'B', path: '/music/b.mp3')]);

    final songs = await db.getAllSongs();
    expect(songs, hasLength(2));
  });
}
