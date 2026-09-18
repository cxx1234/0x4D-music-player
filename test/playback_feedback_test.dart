import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/hud_service.dart';
import 'package:txvziwm/core/services/playback_feedback_service.dart';
import 'package:txvziwm/core/services/player_service.dart';

import 'helpers/silent_audio_engine.dart';

/// 外部播放入口（原生菜单 / 媒体键 / 系统「正在播放」面板）的反馈契约：
/// 执行动作 + 发控件脉冲 + 发 HUD 提示，且**两条入口共用同一套文案**。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StubPlayer player;
  late HudService hud;
  late PlaybackFeedbackService feedback;

  setUp(() {
    player = _StubPlayer();
    hud = HudService();
    feedback = PlaybackFeedbackService(player, hud);
  });

  tearDown(() {
    feedback.dispose();
    hud.dispose();
    player.dispose();
  });

  test('next：换歌后提示「下一首 · 歌名」并发出控件脉冲', () async {
    player.setQueue([_song(1), _song(2)]);

    PlaybackPulse? pulse;
    feedback.pulses.addListener(() => pulse = feedback.pulses.value);

    await feedback.next();

    expect(hud.message?.text, '下一首 · Song 2');
    expect(hud.message?.kind, HudKind.track);
    expect(pulse?.action, PlaybackAction.next);
  });

  test('next：队尾不循环时提示「已是最后一首」（动作仍算一次脉冲）', () async {
    player.setQueue([_song(1), _song(2)], index: 1);
    var pulseCount = 0;
    feedback.pulses.addListener(() => pulseCount++);

    await feedback.next();

    expect(hud.message?.text, '已是最后一首');
    expect(player.currentIndex, 1, reason: '未切歌');
    expect(pulseCount, 1, reason: '按键收到了，控件仍要亮一下');
  });

  test('previous：队首时提示「已是第一首」', () async {
    player.setQueue([_song(1), _song(2)]);

    await feedback.previous();

    expect(hud.message?.text, '已是第一首');
  });

  test('空队列：两个方向都提示「没有播放中的歌曲」', () async {
    await feedback.next();
    expect(hud.message?.text, '没有播放中的歌曲');

    await feedback.previous();
    expect(hud.message?.text, '没有播放中的歌曲');
  });

  test('单曲 + 列表循环：绕回同一首也算切歌，不误报成已到底', () async {
    player.setQueue([_song(1)]);
    player.setRepeatMode(PlayerRepeatMode.all);

    await feedback.next();

    expect(hud.message?.text, '下一首 · Song 1', reason: 'id 与索引都没变，但确实重播了');
  });

  test('播放 / 暂停：结果是结果态文案，两者都发 playPause 脉冲', () async {
    PlaybackAction? lastAction;
    feedback.pulses.addListener(
      () => lastAction = feedback.pulses.value?.action,
    );

    await feedback.play();
    expect(hud.message?.text, '播放中');
    expect(lastAction, PlaybackAction.playPause);

    await feedback.pause();
    expect(hud.message?.text, '已暂停');

    await feedback.togglePlay();
    expect(hud.message?.text, '播放中');
  });

  test('停止：提示「已停止」且不发控件脉冲（界面上没有停止按钮）', () async {
    player.setQueue([_song(1)]);
    await feedback.play();

    var pulseCount = 0;
    feedback.pulses.addListener(() => pulseCount++);

    await feedback.stop();

    expect(hud.message?.text, '已停止');
    expect(player.currentSong, isNull, reason: '停止会清空队列，底栏随即变成未在播放');
    expect(pulseCount, 0, reason: '没有可点亮的停止控件，只靠 HUD');
  });

  test('音量：显示百分比与分级图标，且不发脉冲（滑块自己会动）', () async {
    var pulseCount = 0;
    feedback.pulses.addListener(() => pulseCount++);

    await feedback.adjustVolume(0.1); // 0.3 → 0.4
    expect(hud.message?.text, '40%');
    expect(hud.message?.icon, Icons.volume_down_rounded);
    expect(hud.message?.kind, HudKind.volume);

    await feedback.adjustVolume(0.4); // 0.4 → 0.8
    expect(hud.message?.text, '80%');
    expect(hud.message?.icon, Icons.volume_up_rounded);

    await feedback.adjustVolume(-1); // 钳制到 0
    expect(hud.message?.text, '0%');
    expect(hud.message?.icon, Icons.volume_off_rounded);

    expect(pulseCount, 0);
  });

  test('连续脉冲：seq 自增，连续同一动作也会通知', () async {
    player.setQueue([_song(1), _song(2), _song(3)]);
    final seqs = <int>[];
    feedback.pulses.addListener(() => seqs.add(feedback.pulses.value!.seq));

    await feedback.next();
    await feedback.next();

    expect(seqs, [1, 2], reason: 'ValueNotifier 相同值不通知，负载必须每次都是新对象');
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

/// 直接摆布状态与动作结果的 [PlayerService]：反馈契约只关心"动作前后状态如何
/// 变化"，不需要真实队列/引擎语义（那部分由 player_service_queue_test 覆盖）。
class _StubPlayer extends PlayerService {
  _StubPlayer() : super(SilentAudioEngine());

  final List<Song> _songs = [];
  int _index = 0;
  bool _playing = false;
  double _volume = 0.3;

  /// null = 没有歌曲（空队列）。
  Song? get _current => _songs.isEmpty ? null : _songs[_index];

  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;

  @override
  PlayerRepeatMode get repeatMode => _repeatMode;

  @override
  Song? get currentSong => _current;

  @override
  int get currentIndex => _songs.isEmpty ? 0 : _index;

  @override
  bool get isPlaying => _playing;

  @override
  double get volume => _volume;

  void setQueue(List<Song> songs, {int index = 0}) {
    _songs
      ..clear()
      ..addAll(songs);
    _index = index;
  }

  void setRepeatMode(PlayerRepeatMode mode) => _repeatMode = mode;

  @override
  Future<void> play() async => _playing = true;

  @override
  Future<void> pause() async => _playing = false;

  @override
  Future<void> togglePlay() async => _playing = !_playing;

  @override
  Future<void> stopPlayback() async {
    _songs.clear();
    _index = 0;
    _playing = false;
  }

  @override
  Future<void> next() async {
    if (_songs.isEmpty) return;
    if (_index < _songs.length - 1) {
      _index++;
    } else if (_repeatMode == PlayerRepeatMode.all) {
      _index = 0;
    }
    // 队尾且不循环 → 原地不动，与真实实现一致。
  }

  @override
  Future<void> previous() async {
    if (_songs.isEmpty) return;
    if (_index > 0) _index--;
  }

  @override
  Future<void> adjustVolume(double delta) async {
    _volume = (_volume + delta).clamp(0.0, 1.0);
  }
}
