import 'dart:io';

import 'package:txvziwm/core/services/metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 针对 [MetadataService]（已切换为本地补强的 audio_metadata_reader）的
/// 真实文件集成测试。
///
/// 依赖 `test/music/` 下的大体积真实音频（已被 .gitignore 忽略，仅本地有），
/// 目录不存在时自动跳过，不影响 CI / 他人环境。
///
/// 验证重点：
/// - 三格式（MP3/FLAC/M4A）字段映射：title/artist/albumArtist/album/durationMs
/// - MP3 artist 取 TPE1（本地 fork 已修 TPE1 优先，避免 albumArtist 覆盖）
/// - FLAC artist 列表不再混入 ALBUMARTIST
/// - M4A aART → albumArtist
/// - hasEmbeddedLyrics 标志（三格式均带内嵌歌词；MP3 已补 USLT）
/// - readEmbeddedLyrics 惰性读取（播放时抓取，不读封面）
void main() {
  final musicDir = Directory('test/music');
  final available = musicDir.existsSync();

  final service = MetadataService();

  group('MetadataService（audio_metadata_reader）', () {
    test('MP3：字段映射 + artist 取 TPE1（TPE1≠TPE2 样本）+ 带内嵌歌词', () async {
      if (!available) {
        markTestSkipped('test/music 不存在，跳过真实文件测试');
        return;
      }
      final song = await service.parse('test/music/黒うさP - 下弦の月.mp3');
      expect(song.title, '下弦の月');
      // 该样本 TPE1='黒うさP/96猫'（双歌手）、TPE2='黒うさP'。
      // artist 应取完整 TPE1，而不是被 TPE2（albumArtist）覆盖。
      expect(song.artist, '黒うさP/96猫', reason: 'artist 应为 TPE1（完整值，含 / 分隔）');
      expect(song.albumArtist, '黒うさP', reason: 'albumArtist 应为 TPE2');
      expect(song.album, '月と星の虚構空間');
      expect(song.durationMs, greaterThan(0));
      expect(song.bitrate, isNotNull, reason: 'MP3 应有 bitrate');
      expect(song.hasEmbeddedLyrics, isTrue, reason: '该 MP3 现带 USLT 内嵌歌词');
      expect(song.mimeType, 'audio/mpeg');
    });

    test('FLAC：artist 不含 ALBUMARTIST + 内嵌歌词标志', () async {
      if (!available) {
        markTestSkipped('test/music 不存在，跳过真实文件测试');
        return;
      }
      final song = await service.parse(
        'test/music/幽閉サテライト - 大地に咲く旋律 (with senya).flac',
      );
      expect(song.title, '大地に咲く旋律(with senya)');
      expect(
        song.artist,
        '森永真由美',
        reason: 'FLAC artist 应取 ARTIST，不得混入 ALBUMARTIST',
      );
      expect(
        song.albumArtist,
        '幽閉サテライト',
        reason: 'FLAC ALBUMARTIST → albumArtist',
      );
      expect(song.durationMs, greaterThan(0));
      expect(song.hasEmbeddedLyrics, isTrue, reason: 'FLAC 有 Vorbis LYRICS');
      expect(song.mimeType, 'audio/flac');
    });

    test('M4A：aART → albumArtist + 内嵌歌词标志', () async {
      if (!available) {
        markTestSkipped('test/music 不存在，跳过真实文件测试');
        return;
      }
      final song = await service.parse(
        'test/music/SawanoHiroyuki[nZk] - Unti-L.m4a',
      );
      expect(song.title, 'Unti-L');
      expect(song.artist, 'SawanoHiroyuki[nZk]:ASCA', reason: 'M4A ©ART');
      expect(
        song.albumArtist,
        'SawanoHiroyuki[nZk]',
        reason: 'M4A aART → albumArtist',
      );
      expect(song.album, 'R∃/MEMBER');
      expect(song.durationMs, greaterThan(0));
      expect(song.hasEmbeddedLyrics, isTrue, reason: 'M4A 有 ©lyr');
      expect(song.mimeType, 'audio/mp4');
    });
  });

  group('MetadataService.readEmbeddedLyrics（播放时惰性读内嵌歌词）', () {
    test('MP3 读回 USLT 歌词', () async {
      if (!available) {
        markTestSkipped('test/music 不存在，跳过真实文件测试');
        return;
      }
      final lyrics = await service.readEmbeddedLyrics(
        'test/music/黒うさP - 下弦の月.mp3',
      );
      expect(lyrics, isNotNull, reason: '该 MP3 现带 USLT');
      expect(lyrics!.trim(), isNotEmpty);
    });

    test('FLAC 读回 Vorbis LYRICS（LRC）', () async {
      if (!available) {
        markTestSkipped('test/music 不存在，跳过真实文件测试');
        return;
      }
      final lyrics = await service.readEmbeddedLyrics(
        'test/music/幽閉サテライト - 大地に咲く旋律 (with senya).flac',
      );
      expect(lyrics, isNotNull);
      expect(
        lyrics!,
        contains(RegExp(r'\[\d{1,}:\d{2}')),
        reason: '应含 LRC 时间轴',
      );
    });

    test('M4A 读回 ©lyr（LRC）', () async {
      if (!available) {
        markTestSkipped('test/music 不存在，跳过真实文件测试');
        return;
      }
      final lyrics = await service.readEmbeddedLyrics(
        'test/music/SawanoHiroyuki[nZk] - Unti-L.m4a',
      );
      expect(lyrics, isNotNull);
      expect(
        lyrics!,
        contains(RegExp(r'\[\d{1,}:\d{2}')),
        reason: '应含 LRC 时间轴',
      );
    });
  });

  group('MetadataService.parseAll（受限并发 + 批量 isolate）', () {
    test('批量并发解析 3 个真实文件：结果齐全 + onProgress 累计', () async {
      if (!available) {
        markTestSkipped('test/music 不存在，跳过真实文件测试');
        return;
      }
      const files = [
        'test/music/黒うさP - 下弦の月.mp3',
        'test/music/幽閉サテライト - 大地に咲く旋律 (with senya).flac',
        'test/music/SawanoHiroyuki[nZk] - Unti-L.m4a',
      ];
      final (songs, failures) = await service.parseAll(files);
      expect(failures, isEmpty, reason: '三文件均应解析成功');
      expect(songs, hasLength(3));
      expect(
        songs.map((s) => s.albumArtist),
        containsAll(['黒うさP', '幽閉サテライト', 'SawanoHiroyuki[nZk]']),
        reason: '三格式 albumArtist 均应取到',
      );

      // 进度节流：不保证每文件回调，但最终 processed 必须回拨到总数，
      // 且进度单调递增（不会倒退）。
      var lastProcessed = 0;
      var previous = -1;
      var monotonic = true;
      await service.parseAll(files, onProgress: (p, t, f) {
        if (p < previous) monotonic = false;
        previous = p;
        lastProcessed = p;
      });
      expect(lastProcessed, 3, reason: '收尾应回拨到总数');
      expect(monotonic, isTrue, reason: '进度应单调递增');
    });

    test('空列表：直接返回空结果', () async {
      final (songs, failures) = await service.parseAll(const []);
      expect(songs, isEmpty);
      expect(failures, isEmpty);
    });
  });
}
