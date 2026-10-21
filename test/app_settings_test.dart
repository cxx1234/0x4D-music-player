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

  test('默认 sleepTimerFinishCurrentTrack 为关（老配置缺失该键时行为不变）', () {
    const s = AppSettings();
    expect(s.sleepTimerFinishCurrentTrack, isFalse);
  });

  test('toJson/fromJson 往返保留 sleepTimerFinishCurrentTrack', () {
    const s = AppSettings(sleepTimerFinishCurrentTrack: true);
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.sleepTimerFinishCurrentTrack, isTrue);
  });

  test('fromJson 缺失该键时回退 false', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.sleepTimerFinishCurrentTrack, isFalse);
  });

  test('copyWith 可开关 sleepTimerFinishCurrentTrack', () {
    const s = AppSettings();
    expect(
      s
          .copyWith(sleepTimerFinishCurrentTrack: true)
          .sleepTimerFinishCurrentTrack,
      isTrue,
    );
    expect(
      s
          .copyWith(sleepTimerFinishCurrentTrack: true)
          .copyWith(sleepTimerFinishCurrentTrack: false)
          .sleepTimerFinishCurrentTrack,
      isFalse,
    );
  });

  test('默认 showTrackChangeNotification 为开（老配置缺失该键时行为不变）', () {
    const s = AppSettings();
    expect(s.showTrackChangeNotification, isTrue);
  });

  test('toJson/fromJson 往返保留 showTrackChangeNotification', () {
    const s = AppSettings(showTrackChangeNotification: false);
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.showTrackChangeNotification, isFalse);
  });

  test('fromJson 缺失该键时回退 true', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.showTrackChangeNotification, isTrue);
  });

  test('copyWith 可关闭/恢复 showTrackChangeNotification', () {
    const s = AppSettings();
    expect(
      s
          .copyWith(showTrackChangeNotification: false)
          .showTrackChangeNotification,
      isFalse,
    );
    expect(
      s.copyWith(showTrackChangeNotification: true).showTrackChangeNotification,
      isTrue,
    );
  });

  test('逐字填充默认开启（保留当前观感）', () {
    const s = AppSettings();
    expect(s.lyricWordHighlight, isTrue);
  });

  test('toJson/fromJson 往返保留 lyricWordHighlight', () {
    const s = AppSettings(lyricWordHighlight: false);
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.lyricWordHighlight, isFalse);
  });

  test('fromJson 缺失 lyricWordHighlight 时回退 true', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.lyricWordHighlight, isTrue);
  });

  test('逐字跳动默认关闭（老配置缺失该键时行为不变）', () {
    const s = AppSettings();
    expect(s.lyricWordLift, isFalse);
  });

  test('toJson/fromJson 往返保留逐字跳动字段', () {
    const s = AppSettings(lyricWordLift: true);
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.lyricWordLift, isTrue);
  });

  test('fromJson 缺失逐字跳动键时回退 false', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.lyricWordLift, isFalse);
  });

  test('文本效果强度默认 standard', () {
    const s = AppSettings();
    expect(s.lyricEffectStrength, 'standard');
  });

  test('toJson/fromJson 往返保留 lyricEffectStrength', () {
    const s = AppSettings(lyricEffectStrength: 'strong');
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.lyricEffectStrength, 'strong');
  });

  test('fromJson 缺失 lyricEffectStrength 时回退 standard', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.lyricEffectStrength, 'standard');
  });

  test('切句动画默认 classic', () {
    const s = AppSettings();
    expect(s.lyricLineTransition, 'classic');
  });

  test('toJson/fromJson 往返保留 lyricLineTransition', () {
    const s = AppSettings(lyricLineTransition: 'spring');
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.lyricLineTransition, 'spring');
  });

  test('fromJson 缺失 lyricLineTransition 时回退 classic', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.lyricLineTransition, 'classic');
  });

  test('滑入对齐默认 left', () {
    const s = AppSettings();
    expect(s.lyricSlideAlignment, 'left');
  });

  test('toJson/fromJson 往返保留 lyricSlideAlignment', () {
    const s = AppSettings(lyricSlideAlignment: 'right');
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.lyricSlideAlignment, 'right');
  });

  test('fromJson 缺失 lyricSlideAlignment 时回退 left', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.lyricSlideAlignment, 'left');
  });

  test('行间波浪默认关闭', () {
    const s = AppSettings();
    expect(s.lyricLineWave, isFalse);
  });

  test('toJson/fromJson 往返保留 lyricLineWave', () {
    const s = AppSettings(lyricLineWave: true);
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.lyricLineWave, isTrue);
  });

  test('fromJson 缺失 lyricLineWave 时回退 false', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.lyricLineWave, isFalse);
  });

  test('距离模糊默认关闭', () {
    const s = AppSettings();
    expect(s.lyricDistanceBlur, 'off');
  });

  test('toJson/fromJson 往返保留 lyricDistanceBlur', () {
    const s = AppSettings(lyricDistanceBlur: 'standard');
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.lyricDistanceBlur, 'standard');
  });

  test('fromJson 缺失 lyricDistanceBlur 时回退 off', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.lyricDistanceBlur, 'off');
  });

  test('倒计时圆点默认开启（保留 4.1 默认）', () {
    const s = AppSettings();
    expect(s.lyricCountdown, isTrue);
  });

  test('toJson/fromJson 往返保留 lyricCountdown', () {
    const s = AppSettings(lyricCountdown: false);
    final restored = AppSettings.fromJson(s.toJson());
    expect(restored.lyricCountdown, isFalse);
  });

  test('fromJson 缺失 lyricCountdown 时回退 true', () {
    final restored = AppSettings.fromJson({'musicFolders': []});
    expect(restored.lyricCountdown, isTrue);
  });
}
