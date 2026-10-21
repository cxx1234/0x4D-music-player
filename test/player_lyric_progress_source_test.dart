import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/play_queue.dart';
import 'package:txvziwm/core/services/player_lyric_progress_source.dart';
import 'package:txvziwm/core/services/player_service.dart';

import 'helpers/fake_audio_engine.dart';

Song _song(int id) => Song(
  id: id,
  title: 'Song $id',
  filePath: '/music/$id.mp3',
  fileName: '$id.mp3',
  hasEmbeddedArt: 0,
  hasEmbeddedLyrics: 0,
  dateAdded: DateTime(2024),
  playCount: 0,
  isFavorite: 0,
  isAvailable: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioEngine engine;
  late PlayerService player;
  late PlayerLyricProgressSource source;

  setUp(() {
    engine = FakeAudioEngine();
    player = PlayerService(engine, playQueue: PlayQueue(), random: Random(1));
    source = PlayerLyricProgressSource(player);
  });

  tearDown(() {
    source.dispose();
    player.dispose();
  });

  test('位置、播放态与变更流跟随 PlayerService', () async {
    final events = <void>[];
    final subscription = source.changes.listen(events.add);
    addTearDown(subscription.cancel);

    expect(source.isAdvancing, isFalse);

    await player.playFromList([_song(1)]);
    await pumpEventQueue();
    expect(source.isAdvancing, isTrue);

    engine.setPosition(const Duration(seconds: 12));
    await pumpEventQueue();
    expect(source.position, const Duration(seconds: 12));
    expect(events, isNotEmpty);

    await player.pause();
    await pumpEventQueue();
    expect(source.isAdvancing, isFalse);
  });

  test('暂停时 seek 也会发出变更', () async {
    await player.playFromList([_song(1)]);
    await player.pause();
    await pumpEventQueue();

    var events = 0;
    final subscription = source.changes.listen((_) => events++);
    addTearDown(subscription.cancel);

    await player.seek(const Duration(seconds: 42));
    await pumpEventQueue();

    expect(source.position, const Duration(seconds: 42));
    expect(events, greaterThan(0));
  });
}
