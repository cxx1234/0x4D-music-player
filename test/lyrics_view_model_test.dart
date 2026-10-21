import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/lyrics_view_model.dart';
import 'package:txvziwm/core/utils/lyric_document_parser.dart';
import 'package:txvziwm/core/services/play_queue.dart';
import 'package:txvziwm/core/services/player_service.dart';

import 'helpers/fake_audio_engine.dart';

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

  group('parseLyricContent', () {
    test('LRC 保留空白时间戳（间奏倒计时依据）并拆出翻译', () {
      const lrc = '[00:00.00]Intro\n[00:12.00]\n[00:22.00]Hello 你好';

      final parsed = parseLyricContent(lrc);

      expect(parsed.hasTranslation, isTrue);
      expect(parsed.document.lines.map((line) => line.text), [
        'Intro',
        '',
        'Hello',
      ]);
      expect(parsed.document.lines.last.translation, '你好');
    });

    test('关闭翻译时 hasTranslation 仍按内容事实报告', () {
      const lrc = '[00:22.00]Hello 你好';

      final parsed = parseLyricContent(lrc, includeTranslation: false);

      expect(parsed.hasTranslation, isTrue);
      expect(parsed.document.lines.single.translation, isNull);
    });

    test('QRC 词级时间轴交给库解析，不降级为单行', () {
      const qrc =
          '[1000,2000]Hello(1000,500) world(1500,500)\n'
          '[3000,2000]Bye(3000,500)';

      final parsed = parseLyricContent(qrc);

      expect(parsed.hasTranslation, isFalse);
      expect(parsed.document.lines.length, 2);
      expect(parsed.document.lines.first.text, 'Hello world');
      expect(parsed.document.lines.first.words, isNotEmpty);
      expect(parsed.document.lines.last.text, 'Bye');
    });

    test('YRC 词级时间轴交给库解析', () {
      const yrc = '[1000,2000](1000,500,0)Hello (1500,500,0)world';

      final parsed = parseLyricContent(yrc);

      expect(parsed.document.lines.single.text, 'Hello world');
      expect(parsed.document.lines.single.words, isNotEmpty);
    });

    test('无时间轴文本降级为单行静态歌词', () {
      const text = '第一行\n第二行';

      final parsed = parseLyricContent(text);

      expect(parsed.hasTranslation, isFalse);
      expect(parsed.document.lines.length, 1);
      expect(parsed.document.lines.single.text, text);
      expect(parsed.document.lines.single.start, Duration.zero);
    });
  });

  group('LyricsViewModel 播放进度', () {
    late Directory dir;
    late FakeAudioEngine engine;
    late PlayerService player;
    late LyricsViewModel viewModel;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('lyric_progress_test');
      final audio = '${dir.path}/song.mp3';
      File(
        '${dir.path}/song.lrc',
      ).writeAsStringSync('[00:00.00]First line\n[00:30.00]Second line');

      engine = FakeAudioEngine();
      player = PlayerService(engine, playQueue: PlayQueue(), random: Random(1));
      await player.playFromList([_song(audio)]);

      viewModel = LyricsViewModel(player, isChineseUi: () => true);
      for (var i = 0; i < 50; i++) {
        if (viewModel.controller.document?.lines.isNotEmpty ?? false) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    tearDown(() {
      viewModel.dispose();
      player.dispose();
      dir.deleteSync(recursive: true);
    });

    test('位置由进度源驱动，无需手动 setPosition', () async {
      expect(viewModel.controller.document?.lines.length, 2);
      expect(viewModel.controller.progressSource, isNotNull);
      expect(
        () => viewModel.controller.setPosition(const Duration(seconds: 1)),
        throwsStateError,
      );

      engine.setPosition(const Duration(seconds: 31));
      await pumpEventQueue();

      expect(viewModel.controller.position, const Duration(seconds: 31));
      expect(viewModel.controller.activeLineIndex, 1);
    });
  });
}
