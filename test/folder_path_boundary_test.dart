import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/song_repository.dart';
import 'package:txvziwm/models/scanned_song.dart';

/// 回归：文件夹路径里的 `_`/`%` 不能被 SQL LIKE 当成通配符而误伤兄弟目录。
///
/// `Music_2024` 的 LIKE 模式 `Music_2024/%` 中 `_` 会匹配任意单字符，
/// 从而把 `MusicX2024/` 下的歌也算进来——`deleteFolderSongs` 是**物理删除**，
/// 因此必须由 Dart 侧做精确的根边界判定。
void main() {
  late AppDatabase db;
  late SongRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SongRepository(database: db);
  });

  tearDown(() => db.close());

  ScannedSong song(String path) => ScannedSong(
    filePath: path,
    fileName: path.split('/').last,
    fileSize: 1000,
    title: path.split('/').last,
    mimeType: 'audio/mpeg',
  );

  test('getFolderFilePaths 不误配名字相似的兄弟目录', () async {
    await repo.insertOrUpdateFromScan([
      song('/music/Music_2024/a.mp3'),
      song('/music/MusicX2024/b.mp3'), // 仅差一个字符：LIKE 的 `_` 会匹配它
      song('/music/Music_2024/sub/c.mp3'),
    ]);

    final paths = await db.getFolderFilePaths('/music/Music_2024');
    expect(
      paths,
      unorderedEquals([
        '/music/Music_2024/a.mp3',
        '/music/Music_2024/sub/c.mp3',
      ]),
    );
  });

  test('deleteFolderSongs 只删根内歌曲，不误删兄弟目录', () async {
    await repo.insertOrUpdateFromScan([
      song('/music/Music_2024/a.mp3'),
      song('/music/MusicX2024/b.mp3'),
    ]);

    final deleted = await db.deleteFolderSongs('/music/Music_2024');

    expect(deleted, 1);
    final remaining = (await db.getAllSongs()).map((s) => s.filePath).toList();
    expect(remaining, ['/music/MusicX2024/b.mp3']);
  });

  test('路径恰好等于根本身也算根内', () async {
    await repo.insertOrUpdateFromScan([song('/music/Music_2024')]);

    expect(await db.getFolderFilePaths('/music/Music_2024'), [
      '/music/Music_2024',
    ]);
  });
}
