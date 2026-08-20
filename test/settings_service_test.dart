import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/models/lyric_text_size.dart';
import 'package:txvziwm/core/services/album_art_cache_service.dart';
import 'package:txvziwm/core/services/settings_service.dart';

void main() {
  // path_provider 的 MethodChannel 依赖 binding；不初始化会在普通 test 里
  // 打印 "Binding has not yet been initialized" 噪音。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings 歌词/翻译/主题新字段', () {
    test('默认：字号 medium、显示翻译、主题 system', () {
      const s = AppSettings();
      expect(s.lyricTextSize, 'medium');
      expect(s.showTranslation, isTrue);
      expect(s.themeMode, 'system');
    });

    test('toJson/fromJson 往返保留新字段', () {
      const s = AppSettings(
        lyricTextSize: 'large',
        showTranslation: false,
        themeMode: 'dark',
      );
      final restored = AppSettings.fromJson(s.toJson());
      expect(restored.lyricTextSize, 'large');
      expect(restored.showTranslation, isFalse);
      expect(restored.themeMode, 'dark');
      expect(restored.toJson()['lyricTextSize'], 'large');
      expect(restored.toJson()['showTranslation'], isFalse);
    });

    test('旧 JSON 无新字段时回退默认（向后兼容）', () {
      final restored = AppSettings.fromJson(const {});
      expect(restored.lyricTextSize, 'medium');
      expect(restored.showTranslation, isTrue);
      expect(restored.themeMode, 'system');
    });

    test('fromJson 读取新字段（类型兼容）', () {
      final s = AppSettings.fromJson(const {
        'lyricTextSize': 'small',
        'showTranslation': false,
        'themeMode': 'light',
      });
      expect(s.lyricTextSize, 'small');
      expect(s.showTranslation, isFalse);
      expect(s.themeMode, 'light');
    });
  });

  group('LyricTextSize', () {
    test('fromName 解析 + 未知值/空回退 medium', () {
      expect(LyricTextSize.fromName('small'), LyricTextSize.small);
      expect(LyricTextSize.fromName('large'), LyricTextSize.large);
      expect(LyricTextSize.fromName('huge'), LyricTextSize.medium);
      expect(LyricTextSize.fromName(null), LyricTextSize.medium);
    });

    test('scale/label 与既有值一致（迁移后回归护栏）', () {
      expect(LyricTextSize.small.scale, 0.85);
      expect(LyricTextSize.medium.scale, 1.0);
      expect(LyricTextSize.large.scale, 1.25);
      expect(LyricTextSize.small.label, '小');
      expect(LyricTextSize.medium.label, '中');
      expect(LyricTextSize.large.label, '大');
    });
  });

  group('AlbumArtCacheService.cacheSizeBytes', () {
    test('path_provider 不可用时兜底返回 0 不抛', () async {
      final size = await AlbumArtCacheService().cacheSizeBytes();
      expect(size, 0);
    });
  });
}
