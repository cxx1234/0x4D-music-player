import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/widgets/cached_album_art.dart';

void main() {
  group('albumArtDecodeWidth', () {
    test('有限尺寸按 尺寸×dpr 取整', () {
      expect(albumArtDecodeWidth(44, 1.0), 44);
      expect(albumArtDecodeWidth(44, 2.0), 88);
      expect(albumArtDecodeWidth(140, 1.0), 140);
      expect(albumArtDecodeWidth(140, 2.0), 280);
    });

    test('dpr 非整数时取整', () {
      expect(albumArtDecodeWidth(100, 1.5), 150);
      expect(albumArtDecodeWidth(33, 2.0), 66);
    });

    test('钳制下限 32（极小尺寸也不解出过小图）', () {
      expect(albumArtDecodeWidth(10, 1.0), 32);
      expect(albumArtDecodeWidth(0, 1.0), 32);
      expect(albumArtDecodeWidth(44, 0.5), 32);
    });

    test('钳制上限 2048（超高清原图不超限解码）', () {
      expect(albumArtDecodeWidth(4000, 1.0), 2048);
      expect(albumArtDecodeWidth(1000, 2.5), 2048);
    });

    test('size 无限（网格/拼图占满）用默认值 256×dpr', () {
      expect(albumArtDecodeWidth(double.infinity, 1.0), 256);
      expect(albumArtDecodeWidth(double.infinity, 2.0), 512);
      expect(albumArtDecodeWidth(double.infinity, 3.0), 768);
    });
  });
}
