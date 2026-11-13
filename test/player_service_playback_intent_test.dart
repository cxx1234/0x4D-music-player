import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/play_queue.dart';
import 'package:txvziwm/core/services/player_service.dart';

import 'helpers/fake_audio_engine.dart';

/// [PlayerService.playbackIntentNotifier] 的语义测试。
///
/// 该通知器供「后台恢复播放提示」使用，因此**只认用户手势**：自动推进、
/// 播完收尾、失败跳过、重复下发同一意图都不能上报，否则通知会误弹。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioEngine engine;
  late PlayerService player;
  late List<PlaybackIntent> intents;

  setUp(() {
    engine = FakeAudioEngine();
    player = PlayerService(engine, playQueue: PlayQueue(), random: Random(1));
    intents = <PlaybackIntent>[];
    player.playbackIntentNotifier.addListener(() {
      final event = player.playbackIntentNotifier.value;
      if (event != null) intents.add(event.intent);
    });
  });

  tearDown(() => player.dispose());

  test('暂停后播放 → 上报 play', () async {
    await player.playFromList([_song(1)]);
    intents.clear();

    await player.pause();
    await player.play();

    expect(intents, [PlaybackIntent.pause, PlaybackIntent.play]);
  });

  test('连续两次「暂停 → 播放」都上报（同值也必须能触发）', () async {
    await player.playFromList([_song(1)]);
    intents.clear();

    await player.togglePlay();
    await player.togglePlay();
    await player.togglePlay();
    await player.togglePlay();

    expect(intents, [
      PlaybackIntent.pause,
      PlaybackIntent.play,
      PlaybackIntent.pause,
      PlaybackIntent.play,
    ]);
    expect(player.playbackIntentNotifier.value!.seq, 4);
  });

  test('已在播放时再 play / 已暂停时再 pause → 不上报', () async {
    await player.playFromList([_song(1)]);
    intents.clear();

    await player.play();
    await player.pause();
    await player.pause();

    expect(intents, [PlaybackIntent.pause]);
  });

  test('自动进下一首 / 播完收尾 → 不上报', () async {
    await player.playFromList([_song(1), _song(2)]);
    intents.clear();

    engine.complete();
    await pumpEventQueue();
    expect(player.currentIndex, 1);
    engine.complete();
    await pumpEventQueue();
    expect(player.isPlaying, isFalse, reason: 'repeat off 播完即收尾');

    expect(intents, isEmpty);
  });

  test('加载失败自动跳过 → 不上报', () async {
    engine.badPaths.add('/music/1.mp3');

    await player.playFromList([_song(1), _song(2)]);
    await pumpEventQueue();
    // 自动跳过在 600ms 后才发生（见 PlayerService 的跳过链），等它走完。
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await pumpEventQueue();

    expect(player.currentSong?.id, 2);
    expect(intents, isEmpty);
  });

  test('启动续播的队列尚未加载时 play → 加载并上报 play', () async {
    final queue = PlayQueue()..replace([_song(7)], 0);
    final lazyPlayer = PlayerService(
      engine,
      playQueue: queue,
      random: Random(1),
    );
    addTearDown(lazyPlayer.dispose);
    final events = <PlaybackIntent>[];
    lazyPlayer.playbackIntentNotifier.addListener(() {
      final event = lazyPlayer.playbackIntentNotifier.value;
      if (event != null) events.add(event.intent);
    });

    await lazyPlayer.play();

    expect(engine.loads, ['/music/7.mp3']);
    expect(events, [PlaybackIntent.play]);
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
