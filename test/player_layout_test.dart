import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/utils/display_format.dart';
import 'package:txvziwm/features/player/player_page.dart';

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

  group('fileTypeLabel', () {
    test('mp3 扩展名 → MP3', () {
      expect(fileTypeLabel('song.mp3'), 'MP3');
    });

    test('flac 扩展名 → FLAC', () {
      expect(fileTypeLabel('song.flac'), 'FLAC');
    });

    test('无扩展名返回空串', () {
      expect(fileTypeLabel('song'), '');
    });

    test('点号结尾返回空串', () {
      expect(fileTypeLabel('song.'), '');
    });
  });
}
