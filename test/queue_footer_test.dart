import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/player_service.dart';
import 'package:txvziwm/features/player/queue_view.dart';
import 'package:txvziwm/l10n/app_localizations.dart';

import 'helpers/l10n.dart';

void main() {
  group('queueFooterText', () {
    late AppLocalizations zh;
    late AppLocalizations en;

    setUpAll(() async {
      zh = await loadL10n();
      en = await loadL10n(const Locale('en'));
    });
    test('off + 未随机：顺序播放（未到底）', () {
      expect(queueFooterText(zh, PlayerRepeatMode.off, false), '顺序播放');
    });

    test('off + 未随机 + 到底：顺序播放 · 到底了', () {
      expect(
        queueFooterText(zh, PlayerRepeatMode.off, false, atBottom: true),
        '顺序播放 · 到底了',
      );
    });

    test('off + 随机：随机播放（未到底）', () {
      expect(queueFooterText(zh, PlayerRepeatMode.off, true), '随机播放');
    });

    test('off + 随机 + 到底：随机播放 · 到底了', () {
      expect(
        queueFooterText(zh, PlayerRepeatMode.off, true, atBottom: true),
        '随机播放 · 到底了',
      );
    });

    test('all + 未随机：循环列表（到底也不变）', () {
      expect(queueFooterText(zh, PlayerRepeatMode.all, false), '循环列表播放');
      expect(
        queueFooterText(zh, PlayerRepeatMode.all, false, atBottom: true),
        '循环列表播放',
      );
    });

    test('all + 随机：随机播放（随机循环，到底也不变）', () {
      expect(queueFooterText(zh, PlayerRepeatMode.all, true), '随机播放');
      expect(
        queueFooterText(zh, PlayerRepeatMode.all, true, atBottom: true),
        '随机播放',
      );
    });

    test('one：单曲循环（到底也不变）', () {
      expect(queueFooterText(zh, PlayerRepeatMode.one, false), '单曲循环播放');
      expect(queueFooterText(zh, PlayerRepeatMode.one, true), '单曲循环播放');
      expect(
        queueFooterText(zh, PlayerRepeatMode.one, false, atBottom: true),
        '单曲循环播放',
      );
    });

    test('英文：顺序 / 随机 / 循环 / 到底', () {
      expect(queueFooterText(en, PlayerRepeatMode.off, false), 'Sequential');
      expect(
        queueFooterText(en, PlayerRepeatMode.off, false, atBottom: true),
        'Sequential · End of queue',
      );
      expect(queueFooterText(en, PlayerRepeatMode.off, true), 'Shuffle');
      expect(queueFooterText(en, PlayerRepeatMode.all, false), 'Repeat all');
      expect(queueFooterText(en, PlayerRepeatMode.one, false), 'Repeat one');
    });
  });
}
