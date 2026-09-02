import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/lyrics_view_model.dart';

Song _song(String filePath, {String? lyricsFilePath}) => Song(
  id: 1,
  title: 'T',
  filePath: filePath,
  fileName: 'T.mp3',
  hasEmbeddedArt: 0,
  hasEmbeddedLyrics: 0,
  dateAdded: DateTime(2024),
  playCount: 0,
  isFavorite: 0,
  isAvailable: 1,
  lyricsFilePath: lyricsFilePath,
);

void main() {
  group('resolveLrcPath', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('lyric_test');
    });

    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    test('数据库 lyricsFilePath 优先（即使同名 .lrc 也存在）', () {
      final audio = '${dir.path}/song.mp3';
      File('${dir.path}/song.lrc').writeAsStringSync('[00:00.00]x');
      // 数据库路径必须真实存在才走 DB 分支。
      final otherDir = Directory('${dir.path}/other')..createSync();
      final dbPath = '${otherDir.path}/translated.lrc';
      File(dbPath).writeAsStringSync('[00:00.00]y');
      final song = _song(audio, lyricsFilePath: dbPath);

      expect(resolveLrcPath(song), dbPath);
    });

    test('数据库路径失效（文件不存在）→ 实时兜底同名 .lrc', () {
      final audio = '${dir.path}/song.mp3';
      File('${dir.path}/song.lrc').writeAsStringSync('[00:00.00]x');
      final song = _song(audio, lyricsFilePath: '${dir.path}/gone.lrc');

      expect(resolveLrcPath(song), '${dir.path}/song.lrc');
    });

    test('无数据库路径 → 实时找同名 .lrc', () {
      final audio = '${dir.path}/song.mp3';
      File('${dir.path}/song.lrc').writeAsStringSync('[00:00.00]x');
      final song = _song(audio);

      expect(resolveLrcPath(song), '${dir.path}/song.lrc');
    });

    test('支持 .LRC 大写扩展名兜底', () {
      final audio = '${dir.path}/song.mp3';
      File('${dir.path}/song.LRC').writeAsStringSync('[00:00.00]x');
      final song = _song(audio);

      final result = resolveLrcPath(song);
      expect(result, isNotNull);
      // 大小写不敏感 FS（如 macOS APFS 默认）下 `.lrc` 存在性检查会先命中
      // 该文件并返回 `.lrc` 路径；断言返回路径可访问即可覆盖两种 FS。
      expect(File(result!).existsSync(), isTrue);
    });

    test('无歌词文件 → 返回 null', () {
      final song = _song('${dir.path}/song.mp3');

      expect(resolveLrcPath(song), isNull);
    });
  });
}
