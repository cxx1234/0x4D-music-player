import 'dart:async';

import 'package:txvziwm/core/audio/audio_engine.dart';

/// 带"播完 / 报错 / 位置变化"驱动的假引擎。
///
/// 用途：需要真实队列语义（顺序推进、收尾、失败跳过、睡眠定时钩子）的测试。
/// 只关心上层反馈、不需要播放语义的用例请用 [SilentAudioEngine]。
class FakeAudioEngine implements AudioEngine {
  final List<String> loads = [];
  final List<Duration?> loadPositions = [];
  final List<Duration> seeks = [];

  /// 每次 `setVolume` 的值（淡出音量等断言用；末项即当前值）。
  final List<double> volumes = [];

  /// 这些路径的 [load] 会失败（`loadedPath` 保持 null）并上报错误，模拟坏文件。
  final Set<String> badPaths = {};
  int playCalls = 0;
  int pauseCalls = 0;
  int releaseCalls = 0;
  bool loopSingle = false;
  double volume = 1;

  String? _loadedPath;
  bool _playing = false;
  Duration _position = Duration.zero;
  final Duration _duration = const Duration(minutes: 3);

  final _completionCtrl = StreamController<void>.broadcast();
  final _errorCtrl = StreamController<AudioEngineError>.broadcast();
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration?>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();

  @override
  String? get loadedPath => _loadedPath;

  @override
  bool get isPlaying => _playing;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durationCtrl.stream;

  @override
  Stream<bool> get playingStream => _playingCtrl.stream;

  @override
  Stream<void> get completionStream => _completionCtrl.stream;

  @override
  Stream<AudioEngineError> get errorStream => _errorCtrl.stream;

  /// 可选的加载延迟：用于制造「两次加载交错」的窗口（并发切歌测试）。
  Duration loadDelay = Duration.zero;

  @override
  Future<void> load(String path, {Duration? initialPosition}) async {
    if (loadDelay > Duration.zero) await Future<void>.delayed(loadDelay);
    loads.add(path);
    loadPositions.add(initialPosition);
    if (badPaths.contains(path)) {
      // 真实坏文件的行为：加载失败（loadedPath 为 null）并经错误流上报。
      _loadedPath = null;
      _errorCtrl.add(AudioEngineError('bad file', operation: 'load'));
      return;
    }
    _loadedPath = path;
    _position = initialPosition ?? Duration.zero;
  }

  @override
  Future<void> play() async {
    playCalls++;
    _playing = true;
    _playingCtrl.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _playing = false;
    _playingCtrl.add(false);
  }

  @override
  Future<void> release() async {
    releaseCalls++;
    _loadedPath = null;
    _playing = false;
    _position = Duration.zero;
    _playingCtrl.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _position = position;
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
    volumes.add(volume);
  }

  @override
  Future<void> setLoopSingle(bool loop) async => loopSingle = loop;

  @override
  Future<void> dispose() async {
    await _completionCtrl.close();
    await _errorCtrl.close();
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _playingCtrl.close();
  }

  // ─── 测试驱动 ───

  /// 模拟当前曲目自然播完。
  void complete() => _completionCtrl.add(null);

  /// 模拟引擎报错（加载 / 播放失败）。
  void emitError(String operation) =>
      _errorCtrl.add(AudioEngineError('fake failure', operation: operation));

  /// 直接设定引擎位置（用于「上一首」的 3 秒判定）。
  void setPosition(Duration position) {
    _position = position;
    _positionCtrl.add(position);
  }
}
