import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/utils/m3u.dart';

Song _song(
  String title,
  String filePath, {
  int? durationMs,
  String? artist,
  String? album,
}) => Song(
  id: 1,
  title: title,
  artist: artist,
  album: album,
  filePath: filePath,
  fileName: '$title.mp3',
  hasEmbeddedArt: 0,
  hasEmbeddedLyrics: 0,
  dateAdded: DateTime(2024),
  playCount: 0,
  isFavorite: 0,
  isAvailable: 1,
  durationMs: durationMs,
);

void main() {
  group('buildM3u8', () {
    test('EXTINF 写 Artist - Title，并带 EXTART / EXTALB', () {
      final content = buildM3u8([
        _song(
          '海阔天空',
          '/music/海阔天空.flac',
          durationMs: 320000,
          artist: 'Beyond',
          album: '乐与怒',
        ),
      ]);
      expect(
        content,
        '#EXTM3U\n'
        '#EXTINF:320,Beyond - 海阔天空\n'
        '#EXTART:Beyond\n'
        '#EXTALB:乐与怒\n'
        '/music/海阔天空.flac\n',
      );
    });

    test('无歌手时只写标题，不写 EXTART', () {
      final content = buildM3u8([_song('Lemon', '/music/lemon.mp3')]);
      expect(content, contains('#EXTINF:0,Lemon\n'));
      expect(content, isNot(contains('#EXTART:')));
    });

    test('标题与歌手里的换行被压平', () {
      final content = buildM3u8([
        _song('A\nB', '/music/x.mp3', artist: 'C\r\nD'),
      ]);
      expect(content, contains('#EXTINF:0,C D - A B\n'));
    });
  });

  group('parseM3u', () {
    test('把 EXTINF / EXTART / EXTALB 挂到紧随其后的路径上', () {
      const content =
          '#EXTM3U\n'
          '#EXTINF:320,Beyond - 海阔天空\n'
          '#EXTART:Beyond\n'
          '#EXTALB:乐与怒\n'
          '/music/a.flac\n'
          '\n'
          '# comment\n'
          '/music/b.mp3\r\n';
      final entries = parseM3u(content);

      expect(entries, hasLength(2));
      expect(entries[0].path, '/music/a.flac');
      expect(entries[0].durationSeconds, 320);
      expect(entries[0].label, 'Beyond - 海阔天空');
      expect(entries[0].artist, 'Beyond');
      expect(entries[0].album, '乐与怒');

      // 第二条没有 EXTINF 块，元数据不得串到下一条。
      expect(entries[1].path, '/music/b.mp3');
      expect(entries[1].durationSeconds, 0);
      expect(entries[1].label, isNull);
      expect(entries[1].artist, isNull);
      expect(entries[1].album, isNull);
    });

    test('接受小数秒时长', () {
      final entries = parseM3u('#EXTINF:243.6,Title\n/a.mp3\n');
      expect(entries.single.durationSeconds, 244);
    });
  });

  group('resolveM3uPath', () {
    test('绝对路径归一化后返回', () {
      expect(resolveM3uPath('/music/a.mp3', '/playlists'), '/music/a.mp3');
      expect(resolveM3uPath('/music//a.mp3', '/playlists'), '/music/a.mp3');
    });

    test('相对路径基于歌单目录拼接', () {
      expect(resolveM3uPath('a.mp3', '/music'), '/music/a.mp3');
      expect(resolveM3uPath('../b.mp3', '/music/sub'), '/music/b.mp3');
    });

    test('展开 file:// URI 与 ~', () {
      expect(
        resolveM3uPath('file:///music/a%20b.mp3', '/playlists'),
        '/music/a b.mp3',
      );
      expect(
        resolveM3uPath('~/Music/a.mp3', '/playlists', homeDir: '/Users/x'),
        '/Users/x/Music/a.mp3',
      );
    });
  });
}
