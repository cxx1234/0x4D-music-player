import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/settings_service.dart';

/// 底栏「按播放进度填充」开关的持久化与兼容性。
void main() {
  test('默认 nowPlayingBarFill 为开（老配置缺失该键时行为不变）', () {
    const s = AppSettings();
    expect(s.nowPlayingBarFill, isTrue);
  });

  test('toJson/fromJson 往返保留 nowPlayingBarFill', () {
    const s = AppSettings(nowPlayingBarFill: false);
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.nowPlayingBarFill, isFalse);
  });

  test('fromJson 缺失该键时回退 true', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.nowPlayingBarFill, isTrue);
  });

  test('copyWith 可关闭/恢复 nowPlayingBarFill', () {
    const s = AppSettings();
    expect(s.copyWith(nowPlayingBarFill: false).nowPlayingBarFill, isFalse);
    expect(s.copyWith(nowPlayingBarFill: true).nowPlayingBarFill, isTrue);
  });
}
