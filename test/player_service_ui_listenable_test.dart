import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/play_queue.dart';
import 'package:txvziwm/core/services/player_service.dart';

import 'helpers/fake_audio_engine.dart';

/// [PlayerService.uiListenable] 的覆盖范围测试。
///
/// `PlayerViewModel` 只订阅这个合并通知器（不订阅整个 service），因此凡是
/// UI 会读到的低频状态变化都必须能在它上面触发——否则会出现"图标该翻转但
/// 整块 UI 不重建"，也就是「循环回绕后按钮显示暂停、点了却没反应」那类症状。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioEngine engine;
  late PlayerService player;
  late int notifications;

  setUp(() {
    engine = FakeAudioEngine();
    player = PlayerService(engine, playQueue: PlayQueue(), random: Random(1));
    notifications = 0;
    player.uiListenable.addListener(() => notifications++);
  });

  tearDown(() => player.dispose());

  test('引擎已不在播放时暂停 → 仍通知 UI 重建', () async {
    await player.playFromList([_song(1), _song(2)]);
    // 引擎侧被外部暂停（换源空档 / 完成事件之后 / 原生状态滞后）：播放态
    // 已经是 false，而用户意图仍是 true —— 图标显示「暂停」。
    await engine.pause();
    await pumpEventQueue();
    expect(player.isPlaying, isTrue);
    expect(player.playingNotifier.value, isFalse);
    notifications = 0;

    await player.pause();

    expect(
      notifications,
      greaterThan(0),
      reason: '意图从 true 变 false 必须能触发重建，否则按钮卡在「暂停」',
    );
    expect(player.isPlaying, isFalse);
  });

  test('仅播放进度推进 → 不通知（高频 tick 不得进入 uiListenable）', () async {
    await player.playFromList([_song(1)]);
    notifications = 0;

    engine.setPosition(const Duration(seconds: 2));
    engine.setPosition(const Duration(seconds: 3));
    await pumpEventQueue();

    expect(player.position, const Duration(seconds: 3));
    expect(notifications, 0, reason: '进度刷新应只走 service 自身通知，不能让整页跟着重建');
  });
}

Song _song(int id) => Song(
  id: id,
  title: 'Song $id',
  filePath: '/music/$id.mp3',
  fileName: 'Song $id.mp3',
  hasEmbeddedArt: 0,
  hasEmbeddedLyrics: 0,
  dateAdded: DateTime(2026, 1, 1),
  playCount: 0,
  isFavorite: 0,
  isAvailable: 1,
  durationMs: 180000,
);
