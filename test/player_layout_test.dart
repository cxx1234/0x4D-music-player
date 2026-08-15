import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/features/player/player_page.dart';

void main() {
  group('wideLeftPanelWidth', () {
    test('断点处（760）取最小宽 420，与当前一致', () {
      expect(wideLeftPanelWidth(760), 420);
    });

    test('宽度低于断点仍取最小宽 420（防御）', () {
      expect(wideLeftPanelWidth(500), 420);
    });

    test('1030 处 33%（≈340）未超过最小宽 → 420', () {
      expect(wideLeftPanelWidth(1030), 420);
    });

    test('1280 处取 33% ≈ 422.4', () {
      expect(wideLeftPanelWidth(1280), closeTo(422.4, 0.001));
    });

    test('1920 处取 33% = 633.6', () {
      expect(wideLeftPanelWidth(1920), closeTo(633.6, 0.001));
    });
  });

  group('playerCoverSize', () {
    test('高度充足时受宽度与上限约束', () {
      expect(playerCoverSize(contentWidth: 800, contentHeight: 700), 400);
      expect(playerCoverSize(contentWidth: 340, contentHeight: 700), 340);
    });

    test('高度受限时封面缩小以保证控件在窗口内', () {
      expect(playerCoverSize(contentWidth: 800, contentHeight: 488), 200);
    });

    test('高度无限（窄模式滚动容器）时仅按宽度约束', () {
      expect(
        playerCoverSize(contentWidth: 800, contentHeight: double.infinity),
        400,
      );
      expect(
        playerCoverSize(contentWidth: 380, contentHeight: double.infinity),
        380,
      );
    });
  });
}
