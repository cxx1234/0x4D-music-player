import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import '../utils/logger.dart';
import 'audio_engine.dart';

/// [AudioEngine] 的 `just_audio` 实现。
///
/// ⚠️ **单曲模式**：内部每次都只加载一个 source（`setAudioSource`），因此
/// **不具备** just_audio 队列带来的 gapless 与预取能力 —— 那是引擎持有队列时
/// 才有的特性，而本项目选择由 `PlayQueue` 独占队列（见 docs/AudioEngine-Migration.md
/// §0.4 的互斥性说明）。
///
/// 该实现保留在代码库中的用途：
/// * 作为第二个实现验证 [AudioEngine] 抽象是否真正可替换；
/// * 迁移期间的对照物（`createAudioEngine(AudioEngineKind.justAudio)`）。
class JustAudioEngine implements AudioEngine {
  JustAudioEngine._(this._player) {
    _playbackEventSub = _player.playbackEventStream.listen(_onPlaybackEvent);
    // 引擎自身的异常（PlayerException）转成统一错误类型，与适配器内捕获到的
    // 错误共用同一个错误流，调用方只需订阅一处。
    _errorSub = _player.errorStream.listen((e) => _emitError('event', e));
  }

  /// 创建引擎。
  ///
  /// 顺带清理上一个 isolate（热重启）遗留的原生播放器，避免"幽灵播放器"在
  /// 新播放器首次激活前仍在后台出声/切歌（原 `ServiceLocator._doInitialize`
  /// 中的逻辑迁移至此）。
  static Future<JustAudioEngine> create() async {
    try {
      await JustAudioPlatform.instance.disposeAllPlayers(
        DisposeAllPlayersRequest(),
      );
    } catch (e) {
      AppLogger.warning('Player', 'disposeAllPlayers failed', e);
    }
    return JustAudioEngine._(AudioPlayer());
  }

  final AudioPlayer _player;
  late final StreamSubscription<PlaybackEvent> _playbackEventSub;
  late final StreamSubscription<PlayerException> _errorSub;
  final StreamController<void> _completionCtrl =
      StreamController<void>.broadcast();
  final StreamController<AudioEngineError> _errorCtrl =
      StreamController<AudioEngineError>.broadcast();

  String? _loadedPath;
  bool _loopSingle = false;

  /// 完成事件去重：`playbackEventStream` 会在 completed 状态上重复广播。
  bool _finished = false;

  @override
  String? get loadedPath => _loadedPath;

  @override
  bool get isPlaying => _loadedPath != null && _player.playing;

  @override
  Duration get position =>
      _loadedPath == null ? Duration.zero : _player.position;

  @override
  Duration? get duration => _loadedPath == null ? null : _player.duration;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<void> get completionStream => _completionCtrl.stream;

  @override
  Stream<AudioEngineError> get errorStream => _errorCtrl.stream;

  @override
  Future<void> load(String path, {Duration? initialPosition}) async {
    try {
      _finished = false;
      await _player.setAudioSource(
        AudioSource.file(path),
        initialPosition: initialPosition ?? Duration.zero,
      );
      _loadedPath = path;
      // 换源后重新应用循环设置（引擎侧是 player 级设置，需保持与曲目一致）。
      await setLoopSingle(_loopSingle);
    } catch (e, s) {
      _loadedPath = null;
      _emit('load', e, s);
    }
  }

  @override
  Future<void> play() async {
    if (_loadedPath == null) return;
    _finished = false;
    // ⚠️ just_audio 的 play() 直到「暂停 / 播完」才 complete，直接 await 会
    // 阻塞调用方（队列推进、UI 等），因此这里不 await，只捕获错误。
    unawaited(
      _player.play().catchError(
        (Object e, StackTrace s) => _emit('play', e, s),
      ),
    );
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e, s) {
      _emit('pause', e, s);
    }
  }

  @override
  Future<void> release() async {
    try {
      await _player.stop();
    } catch (e, s) {
      _emit('release', e, s);
    }
    _loadedPath = null;
    _finished = false;
  }

  @override
  Future<void> seek(Duration position) async {
    if (_loadedPath == null) return;
    try {
      await _player.seek(position);
    } catch (e, s) {
      _emit('seek', e, s);
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
    } catch (e, s) {
      _emit('volume', e, s);
    }
  }

  @override
  Future<void> setLoopSingle(bool loop) async {
    _loopSingle = loop;
    try {
      await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    } catch (e, s) {
      _emit('loop', e, s);
    }
  }

  @override
  Future<void> dispose() async {
    await _playbackEventSub.cancel();
    await _errorSub.cancel();
    await _completionCtrl.close();
    await _errorCtrl.close();
    await _player.dispose();
  }

  /// 完成事件：`processingState` 进入 completed 时报一次（去重）。
  void _onPlaybackEvent(PlaybackEvent event) {
    if (event.processingState == ProcessingState.completed) {
      if (!_finished) {
        _finished = true;
        _completionCtrl.add(null);
      }
    } else {
      _finished = false;
    }
  }

  /// 统一错误出口：记日志 + 上报 [errorStream]（实现约定：不抛异常）。
  void _emit(String operation, Object error, [StackTrace? stackTrace]) {
    AppLogger.warning(
      'Player',
      'JustAudioEngine $operation failed',
      error,
      stackTrace,
    );
    _emitError(operation, error);
  }

  void _emitError(String operation, Object error) {
    if (_errorCtrl.isClosed) return;
    _errorCtrl.add(
      AudioEngineError('$error', operation: operation, cause: error),
    );
  }
}
