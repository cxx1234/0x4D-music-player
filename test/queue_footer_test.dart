import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/player_service.dart';
import 'package:txvziwm/features/player/queue_view.dart';

void main() {
  group('queueFooterText', () {
    test('off + 未随机：顺序播放（未到底）', () {
      expect(queueFooterText(PlayerRepeatMode.off, false), '顺序播放');
    });

    test('off + 未随机 + 到底：顺序播放 · 到底了', () {
      expect(
        queueFooterText(PlayerRepeatMode.off, false, atBottom: true),
        '顺序播放 · 到底了',
      );
    });

    test('off + 随机：随机播放（未到底）', () {
      expect(queueFooterText(PlayerRepeatMode.off, true), '随机播放');
    });

    test('off + 随机 + 到底：随机播放 · 到底了', () {
      expect(
        queueFooterText(PlayerRepeatMode.off, true, atBottom: true),
        '随机播放 · 到底了',
      );
    });

    test('all + 未随机：循环列表（到底也不变）', () {
      expect(queueFooterText(PlayerRepeatMode.all, false), '循环列表播放');
      expect(
        queueFooterText(PlayerRepeatMode.all, false, atBottom: true),
        '循环列表播放',
      );
    });

    test('all + 随机：随机循环列表（到底也不变）', () {
      expect(queueFooterText(PlayerRepeatMode.all, true), '随机 · 循环列表播放');
      expect(
        queueFooterText(PlayerRepeatMode.all, true, atBottom: true),
        '随机 · 循环列表播放',
      );
    });

    test('one：单曲循环（到底也不变）', () {
      expect(queueFooterText(PlayerRepeatMode.one, false), '单曲循环播放');
      expect(queueFooterText(PlayerRepeatMode.one, true), '单曲循环播放');
      expect(
        queueFooterText(PlayerRepeatMode.one, false, atBottom: true),
        '单曲循环播放',
      );
    });
  });
}
