import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/app/theme.dart';

void main() {
  group('AppTheme seed 参数化', () {
    test('light/dark 接受 seed 且明暗 brightness 正确', () {
      const seed = Color(0xFF616161);
      expect(
        AppTheme.light(seed: seed).colorScheme.brightness,
        Brightness.light,
      );
      expect(AppTheme.dark(seed: seed).colorScheme.brightness, Brightness.dark);
    });

    test('不同 seed 产出不同 colorScheme.primary（换 seed 即全局换色）', () {
      final graphite = AppTheme.light(seed: const Color(0xFF616161));
      final purple = AppTheme.light(seed: const Color(0xFF673AB7));
      expect(
        graphite.colorScheme.primary,
        isNot(equals(purple.colorScheme.primary)),
      );
    });

    test('同一 seed 的 light/dark primary 不同（明暗各自派生）', () {
      const seed = Color(0xFF616161);
      expect(
        AppTheme.light(seed: seed).colorScheme.primary,
        isNot(equals(AppTheme.dark(seed: seed).colorScheme.primary)),
      );
    });
  });

  group('AppTheme.monochrome 真无彩色', () {
    bool achromatic(Color c) =>
        (c.r - c.g).abs() < 0.001 && (c.g - c.b).abs() < 0.001;

    test('light/dark 灰阶角色全为 R=G=B 纯灰（零色相、不偏色）', () {
      for (final bright in [Brightness.light, Brightness.dark]) {
        final scheme = AppTheme.monochrome(brightness: bright).colorScheme;
        expect(scheme.brightness, bright);
        for (final c in [
          scheme.primary,
          scheme.surface,
          scheme.onSurface,
          scheme.surfaceContainer,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          scheme.outline,
        ]) {
          expect(achromatic(c), isTrue, reason: '$c 应为 R=G=B 纯灰');
        }
      }
    });

    test('error 家族保留语义红（不是灰）', () {
      final scheme = AppTheme.monochrome(
        brightness: Brightness.light,
      ).colorScheme;
      expect(achromatic(scheme.error), isFalse);
    });

    test('monochrome 与彩色 seed 主题明显不同', () {
      final mono = AppTheme.monochrome(brightness: Brightness.light);
      final purple = AppTheme.light(seed: const Color(0xFF673AB7));
      expect(
        mono.colorScheme.primary,
        isNot(equals(purple.colorScheme.primary)),
      );
    });
  });
}
