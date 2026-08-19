import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../database/database.dart';
import '../utils/logger.dart';
import 'play_queue.dart';
import 'service_locator.dart';

/// Available repeat modes for the player.
enum PlayerRepeatMode {
  /// No repeat — stops after the last song.
  off,

  /// Repeats the current song indefinitely.
  one,

  /// Repeats the entire queue.
  all,
}

/// Core audio playback service.
///
/// Wraps [AudioPlayer] from `just_audio` and exposes playback state
/// via [ChangeNotifier].  This is a long-lived singleton — register it
/// in [ServiceLocator] during app startup.
class PlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final PlayQueue _playQueue;

  /// 音频序列是否已交给引擎（惰性加载标志，见 macOS 沙箱时序）。
  bool _sequenceLoaded = false;

  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;
  bool _isShuffled = false;

  /// 播放音量（0.0~1.0）。
  double _volume = 1.0;

  /// 待应用的启动续播位置（构造时从 [PlayQueue] 读取，首次加载序列时消费）。
  Duration? _resumePosition;

  /// 周期兜底落盘当前位置的时间间隔（避免频繁写盘）。
  static const _kPositionSaveInterval = Duration(seconds: 5);
  DateTime _lastPositionSave = DateTime.now();

  /// 连续播放失败计数上限:达到后停止自动跳转(防坏文件死循环)。
  static const int _kMaxConsecutiveErrors = 3;

  /// 最近一次播放错误的用户可读消息(消费即清,供 UI 提示一次)。
  String? _lastPlaybackError;

  /// 连续播放失败计数。
  int _consecutiveErrors = 0;

  /// 队尾播完（repeat off）收尾标志。
  ///
  /// 收尾期间 seek/pause/enqueueFrom 会发出一系列仍带 completed 或旧索引的
  /// 中间事件（macOS 上 seek 到已缓冲的项后甚至停留在 completed、不再发
  /// ready），这些都不能当作权威：否则索引会被拉回最后一首、播完分支被反复
  /// 触发。直到引擎回到 ready（用户点播放等操作会触发）才解除。
  bool _handlingQueueEnd = false;

  // ─── 轻量去重通知器 ────────────────────────────────────
  //
  // 只关心"当前播放高亮"的 UI（音乐库、专辑/播放列表/歌手详情等）应订阅
  // 这些而不是整个 service——后者随 positionStream 每 ~200ms 触发一次，
  // 订阅它会让页面跟着高频重建（保活后 offstage 页也在重建，开销更明显）。

  /// 当前歌曲变化通知器（按歌曲 id 去重，仅在切歌时触发）。
  late final ValueNotifier<Song?> currentSongNotifier = ValueNotifier<Song?>(
    _playQueue.currentSong,
  );

  /// 播放/暂停状态翻转通知器（playing 变化时触发）。
  late final ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(
    _player.playing,
  );

  // ─── Stream subscriptions ──────────────────────────────

  /// 权威事件源：切歌 / seek / 播完等每次引擎变化都会触发。
  StreamSubscription<PlaybackEvent>? _playbackEventSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  /// playing 翻转监听（维护 [playingNotifier]）。
  StreamSubscription<bool>? _playingSub;

  /// 周期对账 watchdog：兜住引擎与 [PlayQueue] 的索引分叉。
  Timer? _reconcileTimer;

  PlayerService({
    PlayQueue? playQueue,
    bool resumePlaybackPosition = true,
    double volume = 1.0,
  }) : _playQueue = playQueue ?? PlayQueue() {
    _volume = volume;
    // Forward PlayQueue changes to this service's listeners（经 _onQueueChanged
    // 汇聚，顺带维护按歌曲去重的 currentSongNotifier）。
    _playQueue.addListener(_onQueueChanged);

    // Restore persisted playback-mode settings (repeat / shuffle).
    _repeatMode = PlayerRepeatMode.values.firstWhere(
      (m) => m.name == _playQueue.repeatModeName,
      orElse: () => PlayerRepeatMode.off,
    );
    _isShuffled = _playQueue.isShuffled;

    // 续播：仅当设置了该选项且保存的位置有效（0 < pos < dur）时应用。
    if (resumePlaybackPosition) {
      final pos = _playQueue.position;
      final dur = _playQueue.duration;
      if (dur > Duration.zero && pos > Duration.zero && pos < dur) {
        _resumePosition = pos;
      }
    }

    _playbackEventSub = _player.playbackEventStream.listen(_onPlaybackEvent);
    _positionSub = _player.positionStream.listen((_) => notifyListeners());
    _durationSub = _player.durationStream.listen((_) => notifyListeners());
    _reconcileTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _reconcile(),
    );
    _playingSub = _player.playingStream.listen(_onPlayingChanged);
    // 应用持久化的音量（引擎默认 1.0，幂等）。
    unawaited(_player.setVolume(_volume));
  }

  /// PlayQueue 变化的统一入口：转发给本 service 的监听者，并维护按歌曲 id
  /// 去重的 [currentSongNotifier]。
  ///
  /// 所有索引变更（playFromList / 引擎切歌 _onPlaybackEvent / reconcile /
  /// 增删移动 / 清空）都经 _playQueue 变更触发，这里一个汇聚点即全覆盖。
  void _onQueueChanged() {
    final song = _playQueue.currentSong;
    if (song?.id != currentSongNotifier.value?.id) {
      currentSongNotifier.value = song;
    }
    notifyListeners();
  }

  /// playing 翻转时同步 [playingNotifier]（playingStream 自带 distinct）。
  void _onPlayingChanged(bool playing) {
    if (playing != playingNotifier.value) {
      playingNotifier.value = playing;
    }
  }

  // ─── Engine ↔ app state reconciliation ─────────────────

  /// 处理引擎权威事件：切歌时原子对齐 [PlayQueue] 索引，队尾播完时收尾。
  ///
  /// just_audio 在 macOS 上每次切歌（自动切歌 / loop-all 回绕 / next /
  /// prev / jump）都会广播一个 playback event，原子携带 currentIndex、
  /// updatePosition、duration 与 processingState——这里是它们对齐的唯一点，
  /// 避免 positionStream 与 sequenceStateStream 跨流不一致。
  void _onPlaybackEvent(PlaybackEvent event) {
    // 队尾播完收尾中：seek/pause/enqueueFrom 会发出一系列仍带 completed 或
    // 旧索引的中间事件，这些都不能当作权威（否则索引被拉回最后一首、播完
    // 分支被反复触发）。只有引擎回到 ready（用户点播放等操作会触发）才解除。
    if (_handlingQueueEnd) {
      if (event.processingState != ProcessingState.ready) {
        notifyListeners();
        return;
      }
      // 引擎已确认回到就绪 → 解除防护，并继续正常处理本事件。
      _handlingQueueEnd = false;
    }

    final idx = event.currentIndex;
    // 序列未加载时的引擎事件（平台初始化/空闲态广播）currentIndex 无意义，
    // 绝不能覆盖 [PlayQueue] 恢复的索引，也不能把位置清零落盘（见 _reconcile）。
    if (_sequenceLoaded &&
        idx != null &&
        idx >= 0 &&
        idx < _playQueue.length &&
        idx != _playQueue.currentIndex) {
      _playQueue.setCurrentIndex(idx);
      // 切歌后立即把新歌的播放位置落盘（此时引擎已同步到新歌）。
      _persistPosition();
    }
    // 队尾播完（repeat off）：回到队列第一首但不播放，用户点播放才继续。
    //
    // 不能在这里从 completed 状态 seek(index:0)：macOS 上这会让引擎实际
    // 停在最后一首的末尾，导致之后 play() 从末尾开始、进度被拉到结尾、
    // 播放/下一首失灵。改为把序列标记为「未加载」并停止引擎（playing=false、
    // 引擎转 idle），下次 play()/next() 会以第一首为起点干净地重建序列——
    // 与「启动恢复队列后尚未播放」的懒加载路径一致。
    if (event.processingState == ProcessingState.completed &&
        _repeatMode == PlayerRepeatMode.off) {
      _handlingQueueEnd = true;
      _playQueue.setCurrentIndex(0);
      _playQueue.setPlaybackState(Duration.zero, Duration.zero);
      _sequenceLoaded = false;
      _resumePosition = Duration.zero;
      unawaited(_player.stop());
    }
    notifyListeners();
  }

  /// 周期 watchdog：把 [PlayQueue] 索引对齐到引擎真实值。
  ///
  /// 兜底场景：切歌广播被 UI 卡死 / 热重载延误，或动态队列编辑
  /// （removeAt / move / playNext 的 [_rebuildSequence] 回退）导致分叉。
  /// 索引没变时不做任何事，因此几乎没有 CPU / UI 开销。
  void _reconcile() {
    // 序列未加载（如启动恢复的队列尚未播放）时引擎 currentIndex 恒为 0，
    // 绝不能用来覆盖 [PlayQueue] 恢复的索引，否则重启后当前歌会被重置成第一首。
    // 队尾播完收尾期间引擎索引可能仍停在最后一首，同样不能对齐。
    if (_playQueue.isEmpty || !_sequenceLoaded || _handlingQueueEnd) return;
    final idx = _player.currentIndex;
    if (idx != null &&
        idx >= 0 &&
        idx < _playQueue.length &&
        idx != _playQueue.currentIndex) {
      _playQueue.setCurrentIndex(idx);
      notifyListeners();
    }
    // 周期兜底落盘当前播放位置（暂停/切歌之外的崩溃、强杀兜底）。
    final now = DateTime.now();
    if (now.difference(_lastPositionSave) >= _kPositionSaveInterval) {
      _lastPositionSave = now;
      _persistPosition();
    }
  }

  /// 把应用状态重新对齐到引擎的真实状态。
  ///
  /// 用户打开"正在播放"界面等需要"立刻看到真相"的时刻调用；
  /// 空队列 / 索引越界时安全返回。
  void resyncFromAudio() {
    // 引擎未加载时同样不能把恢复的索引覆盖成 0，见 [_reconcile]。
    if (_sequenceLoaded) {
      final idx = _player.currentIndex;
      if (idx != null &&
          idx >= 0 &&
          idx < _playQueue.length &&
          idx != _playQueue.currentIndex) {
        _playQueue.setCurrentIndex(idx);
      }
    }
    notifyListeners();
  }

  // ─── Public state ──────────────────────────────────────

  /// The playback queue (delegated to [PlayQueue]).
  List<Song> get queue => _playQueue.songs;

  /// Index of the current song.
  int get currentIndex => _playQueue.currentIndex;

  /// The song currently playing, or `null`.
  Song? get currentSong => _playQueue.currentSong;

  /// Whether audio is currently playing.
  bool get isPlaying => _player.playing;

  /// Current playback position.
  ///
  /// 序列未加载（如启动恢复的队列尚未播放）时回退到上次保存的位置，
  /// 让播放页进度条直接显示续播点。
  Duration get position {
    if (_sequenceLoaded) return _player.position;
    return _playQueue.position;
  }

  /// 播放进度流（约每 200ms 一帧，供歌词等高频跟随订阅）。
  ///
  /// 与 [currentSongNotifier]/[playingNotifier] 同理：只关心进度的订阅方应
  /// 订阅此流而不是整个 service，避免随进度高频重建（broadcast 流，可多订阅）。
  Stream<Duration> get positionStream => _player.positionStream;

  /// Duration of the current song, or [Duration.zero] if unknown.
  ///
  /// 序列未加载时（播完跳回第一首、启动续播）不能用引擎的 duration（可能
  /// 残留上一首的值）：优先上次保存的时长（续播显示），其次用当前歌曲在
  /// 库里扫描到的时长（如播完跳回第一首时保存值已清零）。
  Duration get duration {
    if (_sequenceLoaded) {
      final d = _player.duration;
      if (d != null && d > Duration.zero) return d;
    }
    final saved = _playQueue.duration;
    if (saved > Duration.zero) return saved;
    final ms = currentSong?.durationMs;
    if (ms != null && ms > 0) return Duration(milliseconds: ms);
    return Duration.zero;
  }

  /// Current repeat mode.
  PlayerRepeatMode get repeatMode => _repeatMode;

  /// Whether shuffle is enabled.
  bool get isShuffled => _isShuffled;

  /// 当前音量（0.0~1.0）。
  double get volume => _volume;

  /// 设置音量并应用到引擎（0.0~1.0）。
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  /// 消费并清除最近的播放错误消息(返回 null 表示没有待提示的错误)。
  String? takePlaybackError() {
    final err = _lastPlaybackError;
    _lastPlaybackError = null;
    return err;
  }

  // ─── Queue management ──────────────────────────────────

  /// Replace the queue with [songs] and start playing at [startIndex].
  Future<void> playFromList(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    _playQueue.replace(songs, startIndex);
    // 用户主动选歌播放：放弃启动续播位置。
    _resumePosition = null;

    final sources = songs.map((s) => AudioSource.file(s.filePath)).toList();
    try {
      await _player.setAudioSources(
        sources,
        initialIndex: _playQueue.currentIndex,
      );
      // 序列成功交给引擎后才标记已加载：加载过程中的中间事件
      // （如 currentIndex=0）不能被当作权威，避免播放页闪烁成第一首。
      _sequenceLoaded = true;
      await _applyAudioModes();
      await _player.play();
      _clearPlaybackError();
    } catch (e, s) {
      _reportPlaybackError('playFromList', e, s);
      await _skipOnFailure();
    }
  }

  /// Play a single song (replaces the queue with just this one song).
  Future<void> playFromSong(Song song) async {
    await playFromList([song], startIndex: 0);
  }

  /// Append [songs] to the end of the current queue.
  Future<void> addToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    final wasEmpty = _playQueue.isEmpty;
    _playQueue.append(songs);
    if (wasEmpty) {
      final sources = songs.map((s) => AudioSource.file(s.filePath)).toList();
      _resumePosition = null;
      try {
        await _player.setAudioSources(sources, initialIndex: 0);
        // 序列成功交给引擎后才标记已加载，见 playFromList。
        _sequenceLoaded = true;
        await _applyAudioModes();
        await _player.play();
        _clearPlaybackError();
      } catch (e, s) {
        _reportPlaybackError('addToQueue', e, s);
        await _skipOnFailure();
      }
    } else {
      final newSources = songs
          .map((s) => AudioSource.file(s.filePath))
          .toList();
      // 序列尚未加载（如启动恢复的队列）时跳过：队列已更新，下次
      // play()/_rebuildSequence() 会整体重建，行为与旧版一致。
      if (_sequenceLoaded) {
        try {
          await _player.addAudioSources(newSources);
        } catch (e) {
          AppLogger.warning(
            'Player',
            'addAudioSources failed, falling back to rebuild',
            e,
          );
          await _rebuildSequence();
        }
      }
    }
  }

  // ─── Playback control ──────────────────────────────────

  Future<void> play() async {
    // Lazily build the sequence if no audio source is loaded yet (e.g.
    // restored queue after startup) — play() on an empty player does nothing.
    if (!_sequenceLoaded) {
      if (_playQueue.isEmpty) return;
      try {
        // 首次续播：把启动续播位置交给引擎（仅此一次，消费后清空）。
        final resume = _resumePosition;
        _resumePosition = null;
        await _rebuildSequence(initialPosition: resume);
      } catch (e, s) {
        _reportPlaybackError('play', e, s);
        await _skipOnFailure();
        return;
      }
    }
    try {
      await _player.play();
      _clearPlaybackError();
    } catch (e, s) {
      _reportPlaybackError('play', e, s);
      await _skipOnFailure();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    // 暂停是最常见的“离开播放”动作，立即落盘当前位置。
    _persistPosition();
  }

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    _sequenceLoaded = false;
    _resumePosition = null;
    await _player.stop();
    _playQueue.clear();
  }

  /// Skip to the next song.  Wraps around if [repeatMode] is [PlayerRepeatMode.all].
  Future<void> next() async {
    if (_playQueue.isEmpty) return;

    // No audio source loaded yet (e.g. restored queue after startup) —
    // lazily build the sequence so navigation works without pre-loading
    // files (which would need macOS sandbox permissions too early).
    if (!_sequenceLoaded) {
      final nextIndex = _playQueue.currentIndex + 1;
      if (nextIndex < _playQueue.length) {
        _playQueue.setCurrentIndex(nextIndex);
        _resumePosition = null;
        try {
          // 手动切歌：从新歌开头播放，不使用续播位置。
          await _rebuildSequence(initialPosition: Duration.zero);
          await _player.play();
          _clearPlaybackError();
        } catch (e, s) {
          _reportPlaybackError('next', e, s);
          await _skipOnFailure();
        }
      } else if (_repeatMode == PlayerRepeatMode.all) {
        _playQueue.setCurrentIndex(0);
        _resumePosition = null;
        try {
          await _rebuildSequence(initialPosition: Duration.zero);
          await _player.play();
          _clearPlaybackError();
        } catch (e, s) {
          _reportPlaybackError('next', e, s);
          await _skipOnFailure();
        }
      }
      return;
    }

    try {
      if (_playQueue.currentIndex < _playQueue.length - 1) {
        await _player.seekToNext();
      } else if (_repeatMode == PlayerRepeatMode.all) {
        await _player.seek(Duration.zero, index: 0);
      }
      _clearPlaybackError();
    } catch (e, s) {
      _reportPlaybackError('next', e, s);
      await _skipOnFailure();
    }
    // If repeatMode is `off`, just let playback stop naturally.
  }

  /// Go back to the previous song.
  Future<void> previous() async {
    if (_playQueue.isEmpty) return;

    // Lazily build the sequence if no audio source is loaded yet.
    if (!_sequenceLoaded) {
      final prevIndex = _playQueue.currentIndex - 1;
      if (prevIndex >= 0) {
        _playQueue.setCurrentIndex(prevIndex);
        _resumePosition = null;
        try {
          // 手动切歌：从新歌开头播放，不使用续播位置。
          await _rebuildSequence(initialPosition: Duration.zero);
          await _player.play();
          _clearPlaybackError();
        } catch (e, s) {
          _reportPlaybackError('previous', e, s);
          await _skipOnFailure();
        }
      }
      return;
    }

    try {
      // If more than 3 seconds in, restart the current song.
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
      } else {
        await _player.seekToPrevious();
      }
      _clearPlaybackError();
    } catch (e, s) {
      _reportPlaybackError('previous', e, s);
      await _skipOnFailure();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  /// 切换当前歌曲收藏，并刷新队列中的歌曲对象（UI 经 notify 自动更新）。
  Future<void> toggleFavoriteForCurrent() async {
    final song = _playQueue.currentSong;
    if (song == null) return;
    await ServiceLocator.songRepo.toggleFavorite(song.id);
    final updated = await ServiceLocator.songRepo.getSongById(song.id);
    if (updated != null) {
      _playQueue.replaceSong(updated);
    }
  }

  // ─── Mode switching ────────────────────────────────────

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case PlayerRepeatMode.off:
        _repeatMode = PlayerRepeatMode.all;
        break;
      case PlayerRepeatMode.all:
        _repeatMode = PlayerRepeatMode.one;
        break;
      case PlayerRepeatMode.one:
        _repeatMode = PlayerRepeatMode.off;
        break;
    }
    _playQueue.setRepeatModeName(_repeatMode.name);
    unawaited(_player.setLoopMode(_loopModeFor(_repeatMode)));
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _isShuffled = !_isShuffled;
    _playQueue.setIsShuffled(_isShuffled);
    if (_sequenceLoaded) {
      await _applyAudioModes();
    }
    notifyListeners();
  }

  // ─── Queue management ───────────────────────────────

  /// Remove a song from the queue at [index].
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _playQueue.length) return;
    _playQueue.removeAt(index);
    if (_playQueue.isEmpty) {
      _sequenceLoaded = false;
      await _player.stop();
      return;
    }
    if (_sequenceLoaded) {
      try {
        await _player.removeAudioSourceAt(index);
      } catch (e) {
        AppLogger.warning(
          'Player',
          'removeAudioSourceAt failed, falling back to rebuild',
          e,
        );
        await _rebuildSequence();
      }
    }
  }

  /// Jump to the song at [index] and play.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _playQueue.length) return;
    _playQueue.setCurrentIndex(index);
    try {
      if (!_sequenceLoaded) {
        // 手动选歌播放：从目标歌开头播放，不使用续播位置。
        _resumePosition = null;
        await _rebuildSequence(initialPosition: Duration.zero);
      } else {
        await _player.seek(Duration.zero, index: index);
      }
      await _player.play();
      _clearPlaybackError();
    } catch (e, s) {
      _reportPlaybackError('jumpTo', e, s);
      await _skipOnFailure();
    }
  }

  /// Insert [songs] right after the currently playing song.
  Future<void> playNext(List<Song> songs) async {
    if (songs.isEmpty) return;
    if (_playQueue.isEmpty) {
      await playFromList(songs, startIndex: 0);
      return;
    }
    _playQueue.insertAfterCurrent(songs);
    final newSources = songs.map((s) => AudioSource.file(s.filePath)).toList();
    if (_sequenceLoaded) {
      try {
        await _player.insertAudioSources(
          _playQueue.currentIndex + 1,
          newSources,
        );
      } catch (e) {
        AppLogger.warning(
          'Player',
          'insertAudioSources failed, falling back to rebuild',
          e,
        );
        await _rebuildSequence();
      }
    }
  }

  /// Move a song from [oldIndex] to [newIndex] (drag-to-reorder).
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    _playQueue.move(oldIndex, newIndex);
    if (_sequenceLoaded) {
      try {
        await _player.moveAudioSource(oldIndex, newIndex);
      } catch (e) {
        AppLogger.warning(
          'Player',
          'moveAudioSource failed, falling back to rebuild',
          e,
        );
        await _rebuildSequence();
      }
    }
  }

  /// Clear the entire queue and stop playback.
  Future<void> clearQueue() async {
    _playQueue.clear();
    _sequenceLoaded = false;
    _resumePosition = null;
    await _player.stop();
  }

  /// Sync the queue & audio with the library: removes any song whose
  /// `filePath` is not in [validFilePaths] (e.g. its folder was removed or
  /// the file went missing).
  ///
  /// The audio sequence is only rebuilt when a song was **actually** removed —
  /// a no-op prune (e.g. on a routine library page refresh) leaves the audio
  /// untouched to avoid stutter.
  Future<void> pruneQueue(Set<String> validFilePaths) async {
    final pruned = _playQueue.pruneTo(validFilePaths);

    if (_playQueue.isEmpty) {
      _sequenceLoaded = false;
      await _player.stop();
      return;
    }
    if (pruned && _sequenceLoaded) {
      await _rebuildSequence();
    }
  }

  /// Map a [PlayerRepeatMode] to just_audio's [LoopMode].
  LoopMode _loopModeFor(PlayerRepeatMode mode) {
    switch (mode) {
      case PlayerRepeatMode.off:
        return LoopMode.off;
      case PlayerRepeatMode.one:
        return LoopMode.one;
      case PlayerRepeatMode.all:
        return LoopMode.all;
    }
  }

  /// Apply the current repeat/shuffle settings to the audio engine.
  ///
  /// Called after an audio source is loaded so just_audio's loop and shuffle
  /// modes stay in sync with the persisted settings.
  Future<void> _applyAudioModes() async {
    await _player.setLoopMode(_loopModeFor(_repeatMode));
    if (_isShuffled) {
      await _player.setShuffleModeEnabled(true);
      await _player.shuffle();
    } else {
      await _player.setShuffleModeEnabled(false);
    }
  }

  /// 记录一次播放失败:更新错误消息与连续失败计数。
  ///
  /// 自动跳转由 [_skipOnFailure] 驱动;错误消息由 UI 通过
  /// [takePlaybackError] 消费并提示。
  void _reportPlaybackError(String where, Object e, StackTrace s) {
    _consecutiveErrors++;
    final title = _playQueue.currentSong?.title;
    _lastPlaybackError = '无法播放${title != null ? '：$title' : '该文件'}，已自动跳过';
    AppLogger.error('Player', 'Playback failed in $where', e, s);
    notifyListeners();
  }

  /// 播放成功后清除失败状态(连续计数归零、错误消息清空)。
  void _clearPlaybackError() {
    _consecutiveErrors = 0;
    if (_lastPlaybackError != null) {
      _lastPlaybackError = null;
      notifyListeners();
    }
  }

  /// 播放失败后自动跳到下一首,但连续失败达到上限即停止。
  ///
  /// 延迟 600ms 让错误 SnackBar 先展示;`next()` 内部若再次失败会继续
  /// 走 [_reportPlaybackError] + [_skipOnFailure],形成有界的自动跳过链。
  Future<void> _skipOnFailure() async {
    if (_consecutiveErrors >= _kMaxConsecutiveErrors) {
      _lastPlaybackError = '连续 $_kMaxConsecutiveErrors 次无法播放，已停止自动跳转';
      AppLogger.error(
        'Player',
        'Reached $_kMaxConsecutiveErrors consecutive playback failures; auto-skip stopped',
      );
      notifyListeners();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await next();
  }

  /// 持久化当前歌曲的播放位置与总时长（供启动续播）。
  ///
  /// 仅在序列已加载且时长已知时落盘——避免引擎在未加载/时长未解析时用
  /// 0 或 null 覆盖已恢复的播放位置（just_audio 在 idle 态也可能推送
  /// currentIndex=0 的事件）。
  void _persistPosition() {
    if (!_sequenceLoaded) return;
    final dur = _player.duration;
    if (dur == null) return;
    _playQueue.setPlaybackState(_player.position, dur);
  }

  /// Fallback: rebuild the entire audio sequence from scratch.
  /// Used when a dynamic API call ([addAudioSources]/[removeAudioSourceAt]/
  /// [moveAudioSource]/[insertAudioSources]) fails — this ensures just_audio's
  /// internal sequence stays in sync with [PlayQueue] even if the platform
  /// channel throws.
  /// Fallback: rebuild the entire audio sequence from scratch.
  ///
  /// [initialPosition] 由调用方决定——`play()` 首次续播传保存的位置，
  /// `jumpTo`/`next`/`previous` 手动切歌传 [Duration.zero]（从头播），
  /// 运行时动态编辑回退不传（保持引擎当前位置）。
  Future<void> _rebuildSequence({Duration? initialPosition}) async {
    final songs = _playQueue.songs;
    if (songs.isEmpty) return;
    // 未显式指定初始位置时，若还有待应用的续播位置（恢复队列的首次加载），
    // 用之并清空——续播不再只在 play() 消费，任何首次加载都对齐到续播点，
    // 避免 positionStream 发 0 把歌词/进度拉回开头。
    var pos = initialPosition;
    if (pos == null && _resumePosition != null) {
      pos = _resumePosition;
      _resumePosition = null;
    }
    final sources = songs.map((s) => AudioSource.file(s.filePath)).toList();
    await _player.setAudioSources(
      sources,
      initialIndex: _playQueue.currentIndex.clamp(0, songs.length - 1),
      initialPosition: pos ?? _player.position,
    );
    // 序列成功交给引擎后才标记已加载：加载过程中的中间事件
    // （如 currentIndex=0）不能被当作权威，避免播放页闪烁成第一首。
    _sequenceLoaded = true;
    await _applyAudioModes();
  }

  @override
  void dispose() {
    _playbackEventSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _reconcileTimer?.cancel();
    _player.dispose();
    // 通知器最后释放：cancel 订阅后 _onQueueChanged/_onPlayingChanged 不会再
    // 被触发，避免在已 dispose 的 ValueNotifier 上写入。
    currentSongNotifier.dispose();
    playingNotifier.dispose();
    super.dispose();
  }
}
