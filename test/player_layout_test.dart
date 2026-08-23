import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/features/player/player_page.dart';
import 'package:txvziwm/widgets/song_info_card.dart';

void main() {
  group('wideInfoCardWidth', () {
    test('断点处（1000）取最小宽 500', () {
      expect(wideInfoCardWidth(1000), 500);
    });

    test('宽度低于断点仍取最小宽 500（防御）', () {
      expect(wideInfoCardWidth(500), 500);
    });

    test('1280 处取 40% = 512', () {
      expect(wideInfoCardWidth(1280), closeTo(512, 0.001));
    });

    test('1500 处取 40% = 600', () {
      expect(wideInfoCardWidth(1500), closeTo(600, 0.001));
    });

    test('1920 处取 40% = 768', () {
      expect(wideInfoCardWidth(1920), closeTo(768, 0.001));
    });
  });

  group('fileTypeOf', () {
    Song song(String fileName) => Song(
      id: 1,
      title: 'x',
      filePath: '/a/$fileName',
      fileName: fileName,
      hasEmbeddedArt: 0,
      hasEmbeddedLyrics: 0,
      dateAdded: DateTime(2020),
      playCount: 0,
      isFavorite: 0,
      isAvailable: 1,
    );

    test('mp3 扩展名 → MP3', () {
      expect(fileTypeOf(song('song.mp3')), 'MP3');
    });

    test('flac 扩展名 → FLAC', () {
      expect(fileTypeOf(song('song.flac')), 'FLAC');
    });

    test('无扩展名返回空串', () {
      expect(fileTypeOf(song('song')), '');
    });

    test('点号结尾返回空串', () {
      expect(fileTypeOf(song('song.')), '');
    });
  });
}
