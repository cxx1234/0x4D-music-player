import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/models/lyric_load_state.dart';
import 'package:txvziwm/core/services/lyrics_view_model.dart';
import 'package:txvziwm/core/services/metadata_service.dart';
import 'package:txvziwm/core/services/play_queue.dart';
import 'package:txvziwm/core/services/player_service.dart';

import 'helpers/fake_audio_engine.dart';

Song _song(int id) => Song(
  id: id,
  title: 'Song $id',
  filePath: '/tmp/lyric-switch-$id.mp3',
  fileName: 'Song $id.mp3',
  hasEmbeddedArt: 0,
  hasEmbeddedLyrics: 1,
  dateAdded: DateTime(2024),
  playCount: 0,
  isFavorite: 0,
  isAvailable: 1,
);

class _ControlledMetadata extends MetadataService {
  final Map<String, String?> immediate = {};
  final Map<String, Completer<String?>> pending = {};

  @override
  Future<String?> readEmbeddedLyrics(String filePath) {
    final delayed = pending[filePath];
    if (delayed != null) return delayed.future;
    return Future<String?>.value(immediate[filePath]);
  }
}

Future<void> _waitForState(
  LyricsViewModel viewModel,
  LyricLoadState state,
) async {
  for (var i = 0; i < 400; i++) {
    if (viewModel.loadStateNotifier.value == state) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail(
    'Lyrics state did not become $state '
    '(was ${viewModel.loadStateNotifier.value})',
  );
}

void main() {
  late FakeAudioEngine engine;
  late PlayerService player;
  late LyricsViewModel viewModel;
  late _ControlledMetadata metadata;
  late Song a;
  late Song b;
  late Song c;

  setUp(() async {
    engine = FakeAudioEngine()..loadDelay = const Duration(milliseconds: 10);
    player = PlayerService(engine, playQueue: PlayQueue(), random: Random(1));
    metadata = _ControlledMetadata();
    a = _song(1);
    b = _song(2);
    c = _song(3);
    metadata.immediate[a.filePath] = '[00:00.00]あの日 那一天\n[00:30.00]誓い 誓言';

    await player.playFromList([a, b, c]);
    viewModel = LyricsViewModel(
      player,
      isChineseUi: () => true,
      metadataService: metadata,
    );
    await _waitForState(viewModel, LyricLoadState.ready);

    engine.setPosition(const Duration(seconds: 31));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(viewModel.controller.activeLine?.text, '誓い');
  });

  tearDown(() {
    viewModel.dispose();
    player.dispose();
  });

  test('切歌立即清掉旧歌词，等新曲加载后从 0 开始', () async {
    metadata.pending[b.filePath] = Completer<String?>();

    final switching = player.next();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(viewModel.loadStateNotifier.value, LyricLoadState.loading);
    expect(viewModel.controller.document, isNull);
    expect(viewModel.controller.progressSource, isNull);

    metadata.pending[b.filePath]!.complete('[00:00.00]B0\n[00:30.00]B30');
    await switching;
    await _waitForState(viewModel, LyricLoadState.ready);

    expect(viewModel.controller.document?.lines.map((line) => line.text), [
      'B0',
      'B30',
    ]);
    expect(viewModel.controller.position, Duration.zero);
    expect(viewModel.controller.activeLine?.text, 'B0');
  });

  test('快速 A→B→C：晚到的 B 不覆盖 C', () async {
    metadata.pending[b.filePath] = Completer<String?>();
    metadata.pending[c.filePath] = Completer<String?>();

    final toB = player.next();
    final toC = player.next();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    metadata.pending[c.filePath]!.complete('[00:00.00]C0\n[00:30.00]C30');
    await toC;
    await _waitForState(viewModel, LyricLoadState.ready);
    expect(viewModel.controller.document?.lines.map((line) => line.text), [
      'C0',
      'C30',
    ]);

    metadata.pending[b.filePath]!.complete('[00:00.00]B0\n[00:30.00]B30');
    await toB;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(viewModel.controller.document?.lines.map((line) => line.text), [
      'C0',
      'C30',
    ], reason: '过期请求不能覆盖当前曲目');
  });

  test('暂停切歌：新歌词从 0 开始，恢复播放不跳回旧位置', () async {
    await player.pause();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    metadata.immediate[b.filePath] = '[00:00.00]B0\n[00:30.00]B30';

    await player.next();
    await _waitForState(viewModel, LyricLoadState.ready);

    expect(viewModel.controller.position, Duration.zero);
    expect(viewModel.controller.activeLine?.text, 'B0');

    await player.play();
    engine.setPosition(const Duration(seconds: 31));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(viewModel.controller.activeLine?.text, 'B30');
  });

  test('新曲无歌词：旧内容立即清掉并进入 empty', () async {
    metadata.immediate[b.filePath] = null;

    await player.next();
    await _waitForState(viewModel, LyricLoadState.empty);

    expect(viewModel.controller.document, isNull);
    expect(viewModel.hasTranslationNotifier.value, isFalse);
  });

  test('翻译开关只重解析文档，不重置播放位置', () async {
    expect(viewModel.controller.position, const Duration(seconds: 31));
    expect(viewModel.controller.document?.lines.first.translation, '那一天');

    viewModel.setShowTranslation(false);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(viewModel.controller.position, const Duration(seconds: 31));
    expect(viewModel.controller.document?.lines.first.translation, isNull);
    expect(viewModel.hasTranslationNotifier.value, isTrue);
  });
}
