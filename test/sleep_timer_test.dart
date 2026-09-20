import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/play_queue.dart';
import 'package:txvziwm/core/services/player_service.dart';
import 'package:txvziwm/core/services/sleep_timer_service.dart';
import 'package:txvziwm/widgets/player_bar.dart';
import 'package:txvziwm/widgets/sleep_timer_button.dart';

import 'helpers/fake_audio_engine.dart';

/// 睡眠定时：三种触发方式（倒计时 / 播完当前曲 / 播完当前列表）+ 淡出收尾。
///
/// 逻辑用例刻意用**真实计时器**（把 tickInterval 调小到 20ms）而不是 fake async：
/// 这套逻辑本身就是"定时器 + 异步淡出"，fake async 下要额外操心挂起定时器断言，
/// 收益不抵复杂度。唯一的 widget 用例（入口按钮）走 testWidgets。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioEngine engine;
  late PlayerService player;
  final timers = <SleepTimerService>[];

  SleepTimerService makeTimer({
    Duration fade = Duration.zero,
    Duration tick = const Duration(milliseconds: 20),
    bool Function()? waitForTrackEnd,
  }) {
    final timer = SleepTimerService(
      player,
      fadeDuration: fade,
      tickInterval: tick,
      waitForTrackEnd: waitForTrackEnd,
    );
    timers.add(timer);
    return timer;
  }

  setUp(() {
    engine = FakeAudioEngine();
    player = PlayerService(engine, playQueue: PlayQueue());
  });

  tearDown(() {
    for (final timer in timers) {
      timer.dispose();
    }
    timers.clear();
    player.dispose();
  });

  test('倒计时到点：淡出后暂停，用户音量不受影响且引擎音量还原', () async {
    await player.playFromList([_song(1), _song(2)]);
    expect(player.isPlaying, isTrue);

    final timer = makeTimer(fade: const Duration(milliseconds: 600));
    timer.startForDuration(const Duration(milliseconds: 100));
    expect(timer.mode, SleepTimerMode.duration);
    expect(timer.remaining, isNotNull);

    // 到点后进入淡出：此刻仍在播放，引擎音量已被压低，但用户音量（滑块位置）
    // 不变——淡出走的是引擎级音量。
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(player.isPlaying, isTrue, reason: '淡出尚未结束');
    expect(engine.volume, lessThan(1.0), reason: '正在淡出');
    expect(player.volume, 1.0, reason: '用户音量不该被淡出改写');

    // 淡出结束 → 暂停 + 状态清空 + 提示一次 + 音量还原。
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(player.isPlaying, isFalse);
    expect(engine.pauseCalls, 1);
    expect(timer.isActive, isFalse);
    expect(engine.volume, 1.0, reason: '淡出后必须还原音量，否则下次播放是静音');
    expect(timer.takeNotice(), '睡眠定时结束，已暂停');
    expect(timer.takeNotice(), isNull, reason: '提示只消费一次');
  });

  test('取消定时：不再触发，也不留提示', () async {
    await player.playFromList([_song(1)]);

    final timer = makeTimer();
    timer.startForDuration(const Duration(minutes: 30));
    timer.cancel();
    expect(timer.isActive, isFalse);
    expect(timer.remaining, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(engine.pauseCalls, 0);
    expect(player.isPlaying, isTrue);
    expect(timer.takeNotice(), isNull);
  });

  test('播完当前曲目：停在该曲末尾（释放引擎、位置归零），不推进队列', () async {
    await player.playFromList([_song(1), _song(2), _song(3)]);

    final timer = makeTimer();
    timer.startForEndOfTrack();
    expect(timer.mode, SleepTimerMode.endOfTrack);

    engine.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(player.currentIndex, 0, reason: '不应推进到下一首');
    expect(engine.loads, ['/music/1.mp3'], reason: '不应加载下一首');
    expect(player.isPlaying, isFalse);
    expect(engine.releaseCalls, 1, reason: '曲末收尾释放引擎（再播会重新加载）');
    expect(player.position, Duration.zero);
    expect(timer.isActive, isFalse);
    expect(timer.takeNotice(), '睡眠定时结束，已停止播放');
  });

  test('单曲循环下「播完当前曲目」同样生效（引擎 loop 下仍上报完成事件）', () async {
    await player.playFromList([_song(1), _song(2)]);
    player.toggleSingleRepeat();
    expect(player.repeatMode, PlayerRepeatMode.one);

    final timer = makeTimer();
    timer.startForEndOfTrack();

    engine.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(player.isPlaying, isFalse);
    expect(player.currentIndex, 0);
    expect(timer.isActive, isFalse);
  });

  test('播完当前播放列表：中途继续推进，队尾停下', () async {
    await player.playFromList([_song(1), _song(2)]);

    final timer = makeTimer();
    timer.startForEndOfQueue();

    engine.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(player.currentIndex, 1, reason: '还没到队尾 → 正常推进');
    expect(engine.loads.last, '/music/2.mp3');
    expect(player.isPlaying, isTrue);
    expect(timer.isActive, isTrue);

    engine.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(player.currentIndex, 1, reason: '队尾 → 停下');
    expect(player.isPlaying, isFalse);
    expect(timer.isActive, isFalse);
  });

  test('队列被清空：定时自动取消', () async {
    await player.playFromList([_song(1)]);

    final timer = makeTimer();
    timer.startForDuration(const Duration(minutes: 30));

    await player.clearQueue();
    expect(timer.isActive, isFalse);
  });

  test('设置开启「先播完当前曲」：到点不立即停，转为等待曲末', () async {
    await player.playFromList([_song(1), _song(2)]);

    final timer = makeTimer(
      fade: const Duration(milliseconds: 200),
      waitForTrackEnd: () => true,
    );
    timer.startForDuration(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // 到点后仍在播：模式切成 endOfTrack，没有任何 pause / release。
    expect(player.isPlaying, isTrue);
    expect(engine.pauseCalls, 0);
    expect(engine.releaseCalls, 0);
    expect(timer.mode, SleepTimerMode.endOfTrack);
    expect(timer.remaining, isNull, reason: '等曲末时没有倒计时可显示');
    expect(
      timer.takeNotice(),
      '睡眠定时到点，播完当前曲目后停止',
      reason: '切换等待时提示一次（倒计时突然消失，不提示会像定时失效）',
    );

    // 当前曲自然播完 → 停止，且不推进队列。
    engine.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(player.isPlaying, isFalse);
    expect(player.currentIndex, 0);
    expect(engine.releaseCalls, 1);
    expect(timer.isActive, isFalse);
    expect(timer.takeNotice(), '睡眠定时结束，已停止播放');
  });

  test('设置开启但到点时已暂停：立即收尾，不转入等待', () async {
    await player.playFromList([_song(1)]);
    await player.pause();
    final pausesBefore = engine.pauseCalls;

    final timer = makeTimer(
      fade: const Duration(milliseconds: 200),
      waitForTrackEnd: () => true,
    );
    timer.startForDuration(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // 已暂停时没有"曲末"可等 → 直接收尾（否则定时会永远挂着）。
    expect(timer.isActive, isFalse);
    expect(player.isPlaying, isFalse);
    expect(engine.pauseCalls, pausesBefore, reason: '不该再碰引擎');
    expect(timer.takeNotice(), '睡眠定时结束，已暂停');
  });

  test('淡出期间开始播放新曲目：淡出中止、音量还原、不会把新曲暂停', () async {
    await player.playFromList([_song(1), _song(2)]);

    final timer = makeTimer(fade: const Duration(seconds: 2));
    timer.startForDuration(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(engine.volume, lessThan(1.0), reason: '已在淡出中');

    await player.next(); // 用户主动切歌
    expect(engine.volume, 1.0, reason: '取消淡出应立即还原音量');

    // 越过原淡出结束点：不该再暂停，也不该有 pause 调用。
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(player.isPlaying, isTrue);
    expect(engine.pauseCalls, 0);
  });

  test('剩余时间格式化', () {
    expect(
      formatSleepTimerRemaining(const Duration(minutes: 5, seconds: 9)),
      '5:09',
    );
    expect(formatSleepTimerRemaining(const Duration(minutes: 90)), '1:30:00');
    expect(formatSleepTimerRemaining(Duration.zero), '0:00');
  });

  testWidgets('播放条左侧有睡眠定时入口，菜单可选时长', (tester) async {
    final timer = makeTimer(tick: const Duration(seconds: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerBar(
            player: player,
            theme: ThemeData(),
            onSeek: (_) {},
            sleepTimer: timer,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 菜单展开动画
    expect(find.text('15 分钟'), findsOneWidget);
    expect(find.text('播完当前曲目'), findsOneWidget);
    expect(find.text('播完当前播放列表'), findsOneWidget);

    await tester.tap(find.text('15 分钟'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 菜单收起动画

    expect(timer.mode, SleepTimerMode.duration);
    expect(timer.remaining, isNotNull);
    // 激活后图标变成实心计时器（播放条上唯一能看出"定时开着"的地方）。
    expect(find.byIcon(Icons.timer), findsOneWidget);

    // 收尾：周期计时器必须显式取消，否则 testWidgets 会报"仍有定时器未取消"。
    timer.cancel();
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
