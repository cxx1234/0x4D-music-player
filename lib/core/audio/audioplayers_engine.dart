import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../utils/logger.dart';
import 'audio_engine.dart';

/// [AudioEngine] 的 `audioplayers` 实现（单曲）。
///
/// audioplayers 本身就没有队列概念，因此这里只需专注“播放一个文件”：
/// 队列语义（顺序、随机、重复、队尾收尾）全在 `PlayerService`。
///
/// ### 本类消化的引擎细节（`docs/AudioEngine-Migration.md` 附录 B）
///
/// * **释放模式**：用 `ReleaseMode.stop` 而非默认的 `ReleaseMode.release`
///   —— 后者在播完后会释放资源并清空 source，导致"已加载"状态失真。
/// * **完成事件**：`ReleaseMode.loop` 下 `onPlayerComplete` 仍会触发，因此
///   单曲循环期间主动过滤，避免调用方被误导为"播完了"。
/// * **seek 守卫**：没有 source 时引擎**不会**发送 `onSeekComplete`，而 Dart 侧
///   `seek()` 会等待该事件直到 30s 超时 —— 未加载时必须直接返回。
/// * **进度节流**：默认 `FramePositionUpdater` 每帧调用一次原生方法（60 次/秒），
///   这里改为 200ms，与项目既有的进度/性能假设一致。
/// * **热重启**：6.2.0 起 audioplayers 会在热重启时自行 dispose 遗留播放器，
///   因此无需额外的全局清理调用。
class AudioplayersEngine implements AudioEngine {
  AudioplayersEngine() {
    // 位置流按 ~200ms 节流（默认实现是每帧一次原生调用）。
    _player.positionUpdater = TimerPositionUpdater(
      interval: const Duration(milliseconds: 200),
      getPosition: _player.getCurrentPosition,
    );

    _positionSub = _player.onPositionChanged.listen((p) {
      _position = p;
      _positionCtrl.add(p);
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      _duration = d;
      _durationCtrl.add(d);
    });
    _stateSub = _player.onPlayerStateChanged.listen(
      (s) => _playingCtrl.add(s == PlayerState.playing),
    );
    _completionSub = _player.onPlayerComplete.listen((_) {
      // 单曲循环由引擎原生循环完成，此时的 complete 事件不代表"曲目结束"。
      if (_loopSingle) return;
      _completionCtrl.add(null);
    });
    _errorSub = _player.eventStream.listen(
      (_) {},
      onError: (Object e, StackTrace s) => _emit('event', e, s),
    );
  }

  final AudioPlayer _player = AudioPlayer();

  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<void> _completionSub;
  late final StreamSubscription<void> _errorSub;

  final StreamController<Duration> _positionCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationCtrl =
      StreamController<Duration?>.broadcast();
  final StreamController<bool> _playingCtrl =
      StreamController<bool>.broadcast();
  final StreamController<void> _completionCtrl =
      StreamController<void>.broadcast();
  final StreamController<AudioEngineError> _errorCtrl =
      StreamController<AudioEngineError>.broadcast();

  String? _loadedPath;
  bool _loopSingle = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  String? get loadedPath => _loadedPath;

  @override
  bool get isPlaying =>
      _loadedPath != null && _player.state == PlayerState.playing;

  @override
  Duration get position => _loadedPath == null ? Duration.zero : _position;

  @override
  Duration? get duration => _loadedPath == null ? null : _duration;

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

  @override
  Future<void> load(String path, {Duration? initialPosition}) async {
    final position = initialPosition ?? Duration.zero;
    try {
      if (_loadedPath == path) {
        // 同一文件：无需重新装载，只需定位（保持原来的暂停/播放状态）。
        await _seekInternal(position);
        return;
      }
      // ⚠️ 换源前显式暂停，让状态机走一条**确定**的路径：
      //   · 否则 lib 内部的 `_completePrepared` 会在"正在播放"时自行 stop，
      //     产生一串 playing → stopped → (resume) 的异步事件；
      //   · 其中"迟到的 stopped"会把 UI 刷成"未播放"，而 resume() 又可能因为
      //     Dart 侧 state 仍为 playing 而**提前返回、根本没有下发起播命令**
      //     （实测表现：音频在播但按钮显示"播放"，或跳过链走完却不播）。
      //   · pause() 会等待原生的确认事件，因此 await 之后两侧状态一致。
      if (_player.state == PlayerState.playing) {
        await _player.pause();
      }
      // 释放模式必须先设：它决定播完后的行为。
      await _player.setReleaseMode(
        _loopSingle ? ReleaseMode.loop : ReleaseMode.stop,
      );
      // ⚠️ 加载失败时 audioplayers 通过事件流报错（future 本身可能成功），
      // 因此这里不能只依赖 try/catch，还需 errorStream 兜底（已在构造中接线）。
      await _player.setSourceDeviceFile(path);
      _loadedPath = path;
      _duration = await _player.getDuration() ?? _duration;
      // ⚠️ 必须等 source 准备好之后再 seek：没有 currentItem 时 seek 会等到超时。
      if (position > Duration.zero) {
        await _seekInternal(position);
      } else {
        _position = Duration.zero;
        _positionCtrl.add(Duration.zero);
      }
    } catch (e, s) {
      _loadedPath = null;
      _emit('load', e, s);
    }
  }

  @override
  Future<void> play() async {
    if (_loadedPath == null) return;
    try {
      await _player.resume();
    } catch (e, s) {
      _emit('play', e, s);
    }
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
      await _player.release();
    } catch (e, s) {
      _emit('release', e, s);
    }
    _loadedPath = null;
    _duration = null;
    _position = Duration.zero;
  }

  @override
  Future<void> seek(Duration position) async {
    // ⚠️ 没有 source 时绝不能透到引擎（30s 超时）。
    if (_loadedPath == null) return;
    await _seekInternal(position);
  }

  /// 不做加载状态守卫的内部 seek（供 [load] 在装载完成后调用）。
  Future<void> _seekInternal(Duration position) async {
    try {
      await _player.seek(position);
      _position = position;
      _positionCtrl.add(position);
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
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    } catch (e, s) {
      _emit('loop', e, s);
    }
  }

  @override
  Future<void> dispose() async {
    await _positionSub.cancel();
    await _durationSub.cancel();
    await _stateSub.cancel();
    await _completionSub.cancel();
    await _errorSub.cancel();
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _playingCtrl.close();
    await _completionCtrl.close();
    await _errorCtrl.close();
    // dispose() 内部会先 release，释放原生资源。
    await _player.dispose();
  }

  /// 统一错误出口：记日志 + 上报 [errorStream]（实现约定：不抛异常）。
  void _emit(String operation, Object error, [StackTrace? stackTrace]) {
    AppLogger.warning(
      'Player',
      'AudioplayersEngine $operation failed',
      error,
      stackTrace,
    );
    if (_errorCtrl.isClosed) return;
    _errorCtrl.add(
      AudioEngineError('$error', operation: operation, cause: error),
    );
  }
}
