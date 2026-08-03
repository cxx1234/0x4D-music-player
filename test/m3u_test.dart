import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/core/database/database.dart';
import 'package:flutter_music/core/utils/m3u.dart';

Song _song(String title, String filePath, {int? durationMs}) => Song(
  id: 1,
  title: title,
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
    test('生成 EXTINF 与绝对路径（含中文与空时长）', () {
      final content = buildM3u8([
        _song('海阔天空', '/music/海阔天空.mp3', durationMs: 320000),
        _song('Lemon', '/music/lemon.mp3'),
      ]);
      expect(content, startsWith('#EXTM3U\n'));
      expect(content, contains('#EXTINF:320,海阔天空\n/music/海阔天空.mp3\n'));
      expect(content, contains('#EXTINF:0,Lemon\n/music/lemon.mp3\n'));
    });
  });

  group('parseM3u', () {
    test('去掉注释/EXTINF 与空行，保留路径，兼容 CRLF', () {
      const content =
          '#EXTM3U\n'
          '#EXTINF:320,海阔天空\n'
          '/music/a.mp3\n'
          '\n'
          '# comment\n'
          '/music/b.mp3\r\n';
      expect(parseM3u(content), ['/music/a.mp3', '/music/b.mp3']);
    });
  });

  group('resolveM3uPath', () {
    test('绝对路径原样返回', () {
      expect(resolveM3uPath('/music/a.mp3', '/playlists'), '/music/a.mp3');
    });

    test('相对路径基于歌单目录拼接并归一化', () {
      expect(resolveM3uPath('a.mp3', '/music'), '/music/a.mp3');
      expect(resolveM3uPath('../b.mp3', '/music/sub'), '/music/b.mp3');
    });
  });
}
