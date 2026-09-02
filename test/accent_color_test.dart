import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/models/accent_color.dart';

void main() {
  group('AccentColor 模型', () {
    test('色板 = 跟随系统 + 10 预设，system 无固定 seed，默认 graphite', () {
      expect(AccentColor.values.length, 11);
      expect(AccentColor.values.first, AccentColor.system);
      for (final c in AccentColor.values) {
        expect(c.label, isNotEmpty);
      }
      expect(AccentColor.system.seed, isNull);
      final presets = AccentColor.values.where((c) => !c.followsSystem);
      expect(presets.length, 10);
      for (final c in presets) {
        expect(c.seed, isNotNull);
      }
    });

    test('fromName：已知解析，未知/空值回退 graphite', () {
      expect(AccentColor.fromName('system'), AccentColor.system);
      expect(AccentColor.fromName('graphite'), AccentColor.graphite);
      expect(AccentColor.fromName('deepPurple'), AccentColor.deepPurple);
      expect(AccentColor.fromName('unknown'), AccentColor.graphite);
      expect(AccentColor.fromName(null), AccentColor.graphite);
    });

    test('seedColor：预设回自身；system 直用系统色、缺省回退石墨灰', () {
      expect(AccentColor.deepPurple.seedColor(), AccentColor.deepPurple.seed);
      expect(AccentColor.system.seedColor(), AccentColor.graphite.seed);
      expect(AccentColor.system.seedColor(null), AccentColor.graphite.seed);
      expect(
        AccentColor.graphite.seedColor(const Color(0xFF112233)),
        AccentColor.graphite.seed,
      );
    });

    test('跟随系统「直用」系统强调色，不映射到预设', () {
      const custom = Color(0xFFABCDEF);
      expect(AccentColor.system.seedColor(custom), custom);
      // 系统色非 null 时 even system 也返回该色而非 graphite。
      expect(
        AccentColor.system.seedColor(custom),
        isNot(equals(AccentColor.graphite.seed)),
      );
    });
  });
}
