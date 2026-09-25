import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/play_queue.dart';
import 'package:txvziwm/core/services/player_service.dart';

import 'helpers/fake_audio_engine.dart';

/// PlayerService 的队列语义测试（顺序推进 / 随机排列 / 收尾 / 续播 / 错误跳过）。
///
/// 刻意只覆盖"手测难造场景 + 出错代价高"的部分；引擎实现本身、UI 细节不在此列。
/// 见 docs/AudioEngine-Migration.md §7「测试策略」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioEngine engine;
  late PlayQueue queue;
  late PlayerService player;

  setUp(() {
    engine = FakeAudioEngine();
    queue = PlayQueue();
    player = PlayerService(engine, playQueue: queue, random: Random(1));
  });

  tearDown(() => player.dispose());

  test('顺序播放：next/previous 按队列顺序切换，切歌会加载对应文件', () async {
    await player.playFromList([_song(1), _song(2), _song(3)]);

    expect(engine.loads, ['/music/1.mp3']);
    expect(player.isPlaying, isTrue);

    await player.next();
    expect(player.currentIndex, 1);
    expect(engine.loads.last, '/music/2.mp3');

    // 位置在 3 秒内 → 「上一首」是切歌而非重播当前曲。
    engine.setPosition(Duration.zero);
    await player.previous();
    expect(player.currentIndex, 0);
    expect(engine.loads.last, '/music/1.mp3');
  });

  test('队尾 repeat off：播完收尾——释放引擎、索引回 0、位置归零、不再自动播放', () async {
    await player.playFromList([_song(1), _song(2)]);
    await player.jumpTo(1);
    final playCallsBefore = engine.playCalls;

    engine.complete();
    await pumpEventQueue();

    expect(engine.loadedPath, isNull, reason: '收尾应释放引擎（下次播放重新加载）');
    expect(player.currentIndex, 0);
    expect(player.position, Duration.zero);
    expect(player.isPlaying, isFalse);
    expect(engine.playCalls, playCallsBefore, reason: '不应自动继续播放');
  });

  test('repeat all：末曲播完回绕到首曲并继续播放', () async {
    await player.playFromList([_song(1), _song(2)]);
    player.setPlayMode(PlayerRepeatMode.all, shuffled: false);
    await player.jumpTo(1);

    engine.complete();
    await pumpEventQueue();

    expect(player.currentIndex, 0);
    expect(engine.loads.last, '/music/1.mp3');
    expect(player.isPlaying, isTrue);
  });

  test('repeat one：完成事件被忽略（循环由引擎原生能力完成）', () async {
    await player.playFromList([_song(1), _song(2)]);
    player.toggleSingleRepeat();
    expect(engine.loopSingle, isTrue);

    final loadsBefore = engine.loads.length;
    engine.complete();
    await pumpEventQueue();

    expect(player.currentIndex, 0);
    expect(engine.loads.length, loadsBefore, reason: '不应因完成事件重新加载');
    expect(engine.loopSingle, isTrue);
  });

  test('随机：任意编辑操作后播放顺序仍是一组合法排列', () async {
    player.setPlayMode(PlayerRepeatMode.all, shuffled: true);
    await player.playFromList([for (var i = 0; i < 8; i++) _song(i)]);

    final rnd = Random(7);
    var nextId = 100;
    for (var step = 0; step < 40; step++) {
      switch (rnd.nextInt(5)) {
        case 0:
          await player.addToQueue([_song(nextId++)]);
        case 1:
          await player.playNext([_song(nextId++)]);
        case 2:
          if (player.queue.length > 2) {
            await player.removeFromQueue(rnd.nextInt(player.queue.length));
          }
        case 3:
          if (player.queue.length > 2) {
            final oldIndex = rnd.nextInt(player.queue.length);
            final newIndex = rnd.nextInt(player.queue.length);
            await player.moveInQueue(oldIndex, newIndex);
          }
        case 4:
          await player.next();
      }
      _expectValidShuffleOrder(player, step: step);
    }
  });

  test('续播位置只在首次加载生效一次', () async {
    queue.replace([_song(1), _song(2)], 0);
    queue.setPlaybackState(
      const Duration(seconds: 30),
      const Duration(minutes: 3),
    );
    final resumePlayer = PlayerService(
      engine,
      playQueue: queue,
      random: Random(1),
    );
    addTearDown(resumePlayer.dispose);

    await resumePlayer.play();
    expect(engine.loadPositions.last, const Duration(seconds: 30));

    await resumePlayer.next();
    expect(engine.loadPositions.last, Duration.zero, reason: '手动切歌不应续播');
  });

  test('同一首歌的重复失败只处理一次（不会连跳两首）', () async {
    await player.playFromList([_song(1), _song(2), _song(3)]);

    // 一个底层失败可能同时经"事件流"和"调用抛异常"两条路上报。
    engine.emitError('load');
    engine.emitError('load');
    await pumpEventQueue();

    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(player.currentIndex, 1, reason: '一次失败只应前进一首');
    expect(engine.loads.last, '/music/2.mp3');
  });

  test('自动跳过期间用户手动切歌 → 放弃这次跳过', () async {
    await player.playFromList([_song(1), _song(2), _song(3)]);

    engine.emitError('load');
    await pumpEventQueue();

    // 提示展示期间用户自己点了第 3 首。
    await player.jumpTo(2);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    expect(player.currentIndex, 2, reason: '迟到的自动跳过不应顶掉用户的选择');
    expect(engine.loads.last, '/music/3.mp3');
  });

  test('播放失败：600ms 后自动跳到下一首（重复上报只算一次失败）', () async {
    await player.playFromList([_song(1), _song(2), _song(3)]);

    // 一个底层失败可能同时经"事件流"和"调用抛异常"两条路上报。
    engine.emitError('load');
    engine.emitError('load');
    await pumpEventQueue();
    expect(player.takePlaybackError(), contains('已自动跳过'));

    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(player.currentIndex, 1);
    expect(engine.loads.last, '/music/2.mp3');
  });

  test('坏文件跳过链：走完好文件后必须真的开始播放', () async {
    engine.badPaths.addAll(['/music/1.mp3', '/music/2.mp3']);
    await player.playFromList([_song(1), _song(2), _song(3)]);
    await pumpEventQueue();

    // 两次 600ms 的自动跳过：01 坏 → 02 坏 → 03 好。
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    await pumpEventQueue();

    expect(player.currentIndex, 2);
    expect(engine.loads.last, '/music/3.mp3');
    expect(player.isPlaying, isTrue, reason: '跳过链结束后必须真的起播（曾因沿用引擎瞬时状态而静默加载不播）');
  });

  test('切歌后持久化位置归零（不会把上一首的位置写进新曲）', () async {
    await player.playFromList([_song(1), _song(2)]);
    // 第一首播到 30s 并落盘（pause 会立即落盘当前位置）。
    engine.setPosition(const Duration(seconds: 30));
    await player.pause();
    expect(queue.position, const Duration(seconds: 30));

    await player.next();

    expect(player.currentIndex, 1);
    expect(
      queue.position,
      Duration.zero,
      reason: '切歌后新曲的持久化进度必须归零，否则退出时会写入上一首的位置',
    );
  });

  test('isPlaying 取播放意图：引擎瞬时状态滞后时仍显示播放中', () async {
    await player.playFromList([_song(1), _song(2)]);
    expect(player.isPlaying, isTrue);

    // 引擎侧被外部暂停（模拟换源空档/原生状态滞后），用户意图不变。
    await engine.pause();

    expect(engine.isPlaying, isFalse);
    expect(player.isPlaying, isTrue, reason: '不应因引擎瞬时状态闪成未播放');
  });

  test('并发切歌：过期的加载被丢弃，最终只保留最后一次', () async {
    await player.playFromList([_song(1), _song(2), _song(3)]);
    engine.loadDelay = const Duration(milliseconds: 30);
    engine.loads.clear();

    // 不 await，让两次加载交错（第一次会被代际守卫丢弃）。
    final first = player.next();
    final second = player.next();
    await Future.wait([first, second]);

    expect(player.currentIndex, 2);
    expect(engine.loads.last, '/music/3.mp3');
    expect(player.isPlaying, isTrue);
  });

  test('连续 3 首坏文件后停止自动跳转', () async {
    engine.badPaths.addAll(['/music/1.mp3', '/music/2.mp3', '/music/3.mp3']);
    await player.playFromList([_song(1), _song(2), _song(3), _song(4)]);
    await pumpEventQueue();

    // 手动推进，等价于三次"600ms 后自动跳过"（省掉真实等待）：连续三首加载失败。
    await player.next();
    await pumpEventQueue();
    await player.next();
    await pumpEventQueue();

    expect(player.takePlaybackError(), contains('已停止自动跳转'));
    expect(player.currentIndex, 2, reason: '应停在第 3 首，不再跳到第 4 首');
    expect(engine.loads.contains('/music/4.mp3'), isFalse);

    // 排空挂起的跳过链（此刻已被"用户已切歌"守卫拦下，是 no-op）。
    await Future<void>.delayed(const Duration(milliseconds: 700));
  });
}

// ─── 断言 ────────────────────────────────────────────────

/// 随机模式下 [PlayerService] 对外契约的核心不变量。
void _expectValidShuffleOrder(PlayerService player, {required int step}) {
  final reason = 'step $step';
  final queue = player.queue;
  final effective = player.effectiveQueue;

  expect(effective.length, queue.length, reason: reason);

  // 播放顺序与逻辑队列必须是同一批歌（不多不少、不重复）。
  expect(
    effective.map((s) => s.id).toList()..sort(),
    queue.map((s) => s.id).toList()..sort(),
    reason: '$reason：播放顺序与队列内容不一致',
  );

  // 展示位置 ↔ 逻辑下标必须互逆。
  final mapped = [
    for (var e = 0; e < effective.length; e++)
      player.logicalIndexForEffective(e),
  ]..sort();
  expect(mapped, [for (var i = 0; i < queue.length; i++) i], reason: reason);

  // 高亮必须落在当前歌上。
  expect(
    effective[player.effectiveIndex].id,
    player.currentSong?.id,
    reason: reason,
  );
  expect(
    player.logicalIndexForEffective(player.effectiveIndex),
    player.currentIndex,
    reason: reason,
  );
}

// ─── 测试替身 ───

// FakeAudioEngine 已抽到 helpers/（睡眠定时等测试也要驱动"播完"事件）。

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
