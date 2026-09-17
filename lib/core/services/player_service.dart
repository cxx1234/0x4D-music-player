import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../audio/audio_engine.dart';
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
/// ### 职责划分（2026-09 播放引擎抽象重构）
///
/// * [PlayQueue]：队列数据（唯一真相）+ 持久化。
/// * **本类**：队列的**播放语义** —— 顺序推进、随机排列、重复模式、队尾收尾、
///   续播位置、错误自动跳过。全部是纯 Dart 逻辑，可用 `FakeAudioEngine` 单测。
/// * [AudioEngine]：**只播放一个文件**。不含队列、不含索引、不含 shuffle。
///
/// 因此不再存在"引擎镜像队列"：任何队列编辑（加歌 / 插队 / 删歌 / 拖动排序）
/// 都只是 [PlayQueue] 的操作，引擎只在"当前曲目发生变化"时才重新加载。
/// 详见 `docs/AudioEngine-Migration.md`。
class PlayerService extends ChangeNotifier {
  PlayerService(
    this._engine, {
    PlayQueue? playQueue,
    bool resumePlaybackPosition = true,
    double volume = 1.0,
    math.Random? random,
  }) : _playQueue = playQueue ?? PlayQueue(),
       _resumePlaybackEnabled = resumePlaybackPosition,
       _random = random ?? math.Random() {
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
    _rebuildOrder(keepCurrentFirst: true);

    // 续播：仅当设置了该选项且保存的位置有效（0 < pos < dur）时应用。
    if (resumePlaybackPosition) {
      final pos = _playQueue.position;
      final dur = _playQueue.duration;
      if (dur > Duration.zero && pos > Duration.zero && pos < dur) {
        _resumePosition = pos;
      }
    }

    _positionSub = _engine.positionStream.listen((_) => _notify());
    _durationSub = _engine.durationStream.listen((_) => _notify());
    _playingSub = _engine.playingStream.listen(_onPlayingChanged);
    _completionSub = _engine.completionStream.listen((_) => _onCompleted());
    _errorSub = _engine.errorStream.listen(_onEngineError);
    // 周期兜底落盘当前位置（崩溃 / 强杀兜底；索引对账已不再需要，因为引擎
    // 不再持有队列索引）。
    _positionSaveTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _maybePersistPosition(),
    );
    // 应用持久化的音量与循环设置（幂等）。
    unawaited(_engine.setVolume(_volume));
    unawaited(_engine.setLoopSingle(_repeatMode == PlayerRepeatMode.one));
  }

  final AudioEngine _engine;
  final PlayQueue _playQueue;
  final math.Random _random;

  /// 引擎当前已加载的**逻辑队列索引**；`null` = 尚未加载。
  ///
  /// 对应重构前的 `_sequenceLoaded` 标志：未加载时引擎的 position/duration
  /// 不可信，且启动恢复的队列还不能预加载文件（macOS 沙箱需要 security-scoped
  /// bookmark 先恢复权限）。
  int? _loadedIndex;

  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;
  bool _isShuffled = false;

  /// 进入单曲循环前的重复模式（退出单曲循环时恢复）。
  PlayerRepeatMode? _preSingleRepeat;

  /// 播放音量（0.0~1.0）。
  double _volume = 1.0;

  /// 续播开关：关闭时未加载的 position/duration 不回退到上次保存值，
  /// 避免界面显示上次播放位置（实际会从头播放）。
  /// 注意：不影响当前播放歌曲信息与总时长（后者仍用 currentSong 兜底）。
  final bool _resumePlaybackEnabled;

  /// 待应用的启动续播位置（构造时从 [PlayQueue] 读取，首次加载时消费）。
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

  /// 自动推进的重入保护（完成事件与手动切歌不应叠加执行）。
  bool _advancing = false;

  /// 加载事务深度：>0 表示正在把新曲目交给引擎。
  ///
  /// 期间引擎事件（duration / playing / position）不逐条通知 UI，攒到事务结束
  /// 统一发一次——否则"点一首歌"会连发 5~6 次重建，放大滚动视图等布局竞态的
  /// 窗口（见 docs/AudioEngine-Migration.md 的加固记录）。
  int _loadDepth = 0;
  bool _notifyPending = false;

  /// 合并通知的上限时间（兜底）：即使某个加载卡住，UI 也不会被永久冻结。
  static const _kNotifyCoalesceWindow = Duration(milliseconds: 250);
  Timer? _notifyFlushTimer;

  /// 正在处理失败的曲目路径。
  ///
  /// **同一首歌的失败只处理一次**：一个底层失败可能同时经"事件流"和"调用抛异常"
  /// 两条路上报（audioplayers 即是如此）。不去重的话会连跳两首歌、并对同一个
  /// 文件发起两个并发加载（其一会卡到引擎超时，期间 UI 通知被合并压制）。
  /// 在成功加载下一首时复位（[_clearPlaybackError]）。
  String? _failingPath;

  /// 上一次加载时"是否需要播放"的意图。
  ///
  /// ⚠️ **不能用 `_engine.isPlaying` 代替**：加载失败的曲目会让引擎处于"未播放"
  /// 状态，事后用它判断会让跳过链上的每一首都变成"静默加载、不播放"（实测：坏文件
  /// 连跳两次后，停在好文件上却不播）。用意图判断才能让整条链保持一致。
  bool _shouldPlay = false;

  // ─── 播放顺序表（随机排列）─────────────────────────────

  /// 播放顺序：`_order[slot]` = 逻辑队列索引。
  ///
  /// 始终是 `0..length-1` 的一个排列（未开启随机时为恒等排列）。
  /// 取代了重构前由 just_audio 引擎维护的 `effectiveIndices`。
  List<int> _order = [];

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
    _engine.isPlaying,
  );

  /// 供 UI 订阅的合并通知器：切歌 / 播放态翻转 / 队列结构变化。
  ///
  /// 播放进度（~200ms）**不**在此列——需要随进度刷新的 UI（如播放进度条）
  /// 应单独订阅本 service 或 [positionStream]，避免整页随进度连带重建。
  late final Listenable uiListenable = Listenable.merge([
    currentSongNotifier,
    playingNotifier,
    _playQueue,
  ]);

  // ─── Stream subscriptions ──────────────────────────────

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<void>? _completionSub;
  StreamSubscription<AudioEngineError>? _errorSub;

  /// 周期落盘 watchdog。
  Timer? _positionSaveTimer;

  /// 统一的变更通知出口：加载事务期间合并为一次。
  ///
  /// 合并有上限（[_kNotifyCoalesceWindow]）：万一某个加载卡住（引擎超时未归），
  /// UI 也不会被永久冻结。
  void _notify() {
    if (_loadDepth == 0) {
      notifyListeners();
      return;
    }
    _notifyPending = true;
    _notifyFlushTimer ??= Timer(_kNotifyCoalesceWindow, _flushPendingNotify);
  }

  /// 把合并期间攒下的通知发出去（事务结束或达到上限时长时调用）。
  void _flushPendingNotify() {
    _notifyFlushTimer?.cancel();
    _notifyFlushTimer = null;
    if (!_notifyPending) return;
    _notifyPending = false;
    notifyListeners();
  }

  /// PlayQueue 变化的统一入口：转发给本 service 的监听者，并维护按歌曲 id
  /// 去重的 [currentSongNotifier]。
  ///
  /// ⚠️ 本方法**不负责**播放顺序表维护——`PlayQueue` 的通知也包含
  /// `setCurrentIndex` 这类不该触发重排的调用，顺序表由显式的队列变更方法维护。
  void _onQueueChanged() {
    final song = _playQueue.currentSong;
    if (song?.id != currentSongNotifier.value?.id) {
      currentSongNotifier.value = song;
    }
    _notify();
  }

  /// playing 翻转时同步 [playingNotifier]。
  void _onPlayingChanged(bool playing) {
    if (playing != playingNotifier.value) {
      playingNotifier.value = playing;
    }
    _notify();
  }

  // ─── 播放顺序表维护 ───────────────────────────────────

  /// 重建播放顺序表。
  ///
  /// [keepCurrentFirst] 为 `true` 时把当前曲目放到首位（点歌播放 / 切歌后
  /// 保持当前曲继续），否则保持随机排列的原始顺序（每轮重洗）。
  void _rebuildOrder({bool keepCurrentFirst = false}) {
    final n = _playQueue.length;
    final order = List<int>.generate(n, (i) => i);
    if (_isShuffled) {
      order.shuffle(_random);
      if (keepCurrentFirst && n > 0) {
        final current = _playQueue.currentIndex.clamp(0, n - 1);
        order.remove(current);
        order.insert(0, current);
      }
    }
    _order = order;
  }

  /// 追加了 [count] 首（逻辑索引 `from .. from+count-1`）。
  void _onSongsAppended(int from, int count) {
    if (count <= 0) return;
    _order = [
      ..._order.where((i) => i < from),
      for (var i = from; i < from + count; i++) i,
    ];
  }

  /// 在当前位置之后插入了 [count] 首（逻辑索引 `current+1 .. current+count`）。
  void _onSongsInsertedAfterCurrent(int count) {
    if (count <= 0) return;
    final insertAt = _playQueue.currentIndex + 1;
    final shifted = [for (final i in _order) i >= insertAt ? i + count : i];
    final slot = shifted.indexOf(_playQueue.currentIndex) + 1;
    shifted.insertAll(slot, [for (var k = 0; k < count; k++) insertAt + k]);
    _order = shifted;
  }

  /// 逻辑索引 [removedIndex] 被删除。
  void _onSongRemoved(int removedIndex) {
    _order = [
      for (final i in _order)
        if (i != removedIndex) (i > removedIndex ? i - 1 : i),
    ];
  }

  /// 逻辑索引 [oldIndex] 移动到 [newIndex]（与 `PlayQueue.move` 同一套索引规则）。
  ///
  /// 保持"每首歌仍在原来的播放槽位"——拖动排序不应打乱随机播放的既有顺序。
  void _onSongMoved(int oldIndex, int newIndex) {
    _order = [for (final i in _order) _relabelForMove(i, oldIndex, newIndex)];
  }

  static int _relabelForMove(int index, int oldIndex, int newIndex) {
    if (index == oldIndex) return newIndex;
    var j = index;
    if (oldIndex < newIndex) {
      if (j > oldIndex && j <= newIndex) j -= 1;
    } else {
      if (j >= newIndex && j < oldIndex) j += 1;
    }
    return j;
  }

  /// 当前曲目在播放顺序中的槽位。
  int get _currentSlot {
    final slot = _order.indexOf(_playQueue.currentIndex);
    return slot < 0 ? 0 : slot;
  }

  // ─── 引擎加载 ─────────────────────────────────────────

  /// 当前曲目是否已交给引擎。
  bool get _isLoaded => _loadedIndex != null;

  /// 把当前曲目加载进引擎（可选自动播放）。
  ///
  /// 返回是否加载成功；失败时错误已由 [AudioEngine.errorStream] 上报，并由
  /// [_onEngineError] 统一走"提示 + 自动跳过"。
  Future<bool> _loadCurrent({required bool autoPlay}) async {
    // 加载事务：把这次加载期间产生的通知合并为一次 UI 重建。
    _loadDepth++;
    try {
      final song = _playQueue.currentSong;
      if (song == null) {
        _loadedIndex = null;
        return false;
      }
      // 续播位置只在"首次加载"消费一次（手动切歌会提前清空）。
      final position = _resumePosition ?? Duration.zero;
      _resumePosition = null;
      _loadedIndex = _playQueue.currentIndex;
      // 记下本次的播放意图：跳过链 / 自动推进后续都以它为准（而非引擎的瞬时状态）。
      _shouldPlay = autoPlay;
      await _engine.setVolume(_volume);
      await _engine.setLoopSingle(_repeatMode == PlayerRepeatMode.one);
      await _engine.load(song.filePath, initialPosition: position);
      if (_engine.loadedPath == null) {
        _loadedIndex = null;
        return false;
      }
      if (autoPlay) await _engine.play();
      // 加载（并起播）成功 → 复位连续失败计数，避免"隔了很久的旧失败"累积到上限。
      _clearPlaybackError();
      return true;
    } finally {
      _loadDepth--;
      if (_loadDepth == 0) _flushPendingNotify();
    }
  }

  /// 切到播放顺序中的 [slot]（逻辑索引由顺序表换算）。
  Future<void> _skipToSlot(int slot, {bool? autoPlay}) async {
    if (slot < 0 || slot >= _order.length) return;
    // 默认沿用当前播放意图（而非引擎的瞬时状态，见 [_shouldPlay]）。
    final play = autoPlay ?? _shouldPlay;
    final index = _order[slot];
    _playQueue.setCurrentIndex(index);
    // 手动 / 自动切歌都从曲目开头播放，不使用续播位置。
    _resumePosition = null;
    _loadedIndex = null;
    await _loadCurrent(autoPlay: play);
  }

  // ─── 引擎事件 ─────────────────────────────────────────

  /// 单曲自然播完 → 推进队列。
  Future<void> _onCompleted() async {
    // 单曲循环由引擎原生循环完成；部分引擎（audioplayers）仍会上报完成事件。
    if (_repeatMode == PlayerRepeatMode.one) return;
    if (_advancing || _playQueue.isEmpty) return;
    _advancing = true;
    try {
      final slot = _currentSlot;
      if (slot + 1 < _order.length) {
        await _skipToSlot(slot + 1, autoPlay: true);
      } else if (_repeatMode == PlayerRepeatMode.all) {
        // 一轮播完：随机时重洗排列，从新排列的首曲继续。
        if (_isShuffled) _rebuildOrder();
        await _skipToSlot(0, autoPlay: true);
      } else {
        await _finishQueue();
      }
    } finally {
      _advancing = false;
    }
  }

  /// 队尾播完（repeat off）收尾：停止播放、索引回到队列第一首、位置归零。
  ///
  /// 重构前用多步 hack 实现（`_handlingQueueEnd` 防护 + 重建整个序列，并需
  /// 防御 macOS 上"seek 到已缓冲项后停在 completed"的中间事件）；现在只需释放
  /// 引擎并归零状态。
  Future<void> _finishQueue() async {
    _shouldPlay = false;
    _loadedIndex = null;
    _resumePosition = Duration.zero;
    await _engine.release();
    _playQueue.setCurrentIndex(0);
    _playQueue.setPlaybackState(Duration.zero, Duration.zero);
    notifyListeners();
  }

  /// 引擎错误（加载 / 播放 / 跳转失败）→ 提示用户并自动跳过。
  ///
  /// ⚠️ 同一首歌的失败只处理一次（见 [_failingPath]）：否则一次失败会触发两次
  /// 自动跳过（实测表现为"漏掉一首歌"）并重复弹提示。
  void _onEngineError(AudioEngineError error) {
    final path = _playQueue.currentSong?.filePath;
    if (path != null && path == _failingPath) return;
    _failingPath = path;
    _reportPlaybackError(
      error.operation ?? 'engine',
      error.cause ?? error,
      null,
    );
    unawaited(_skipOnFailure(path));
  }

  /// 周期兜底落盘当前位置。
  void _maybePersistPosition() {
    final now = DateTime.now();
    if (now.difference(_lastPositionSave) < _kPositionSaveInterval) return;
    _lastPositionSave = now;
    _persistPosition();
  }

  // ─── Public state ──────────────────────────────────────

  /// The playback queue (delegated to [PlayQueue]).
  List<Song> get queue => _playQueue.songs;

  /// Index of the current song.
  int get currentIndex => _playQueue.currentIndex;

  /// The song currently playing, or `null`.
  Song? get currentSong => _playQueue.currentSong;

  /// Whether audio is currently playing.
  bool get isPlaying => _engine.isPlaying;

  /// Current playback position.
  ///
  /// 未加载（如启动恢复的队列尚未播放）时回退到上次保存的位置，
  /// 让播放页进度条直接显示续播点。
  Duration get position {
    if (_isLoaded) return _engine.position;
    // 续播关闭时，未加载序列不回退到上次保存的位置（否则界面会显示
    // 上次播放位置，即便实际会从头播放）。
    if (!_resumePlaybackEnabled) return Duration.zero;
    return _playQueue.position;
  }

  /// 播放进度流（约每 200ms 一帧，供歌词等高频跟随订阅）。
  ///
  /// 与 [currentSongNotifier]/[playingNotifier] 同理：只关心进度的订阅方应
  /// 订阅此流而不是整个 service，避免随进度高频重建（broadcast 流，可多订阅）。
  Stream<Duration> get positionStream => _engine.positionStream;

  /// Duration of the current song, or [Duration.zero] if unknown.
  ///
  /// 未加载时（播完跳回第一首、启动续播）不能用引擎的 duration（可能残留
  /// 上一首的值）：优先上次保存的时长（续播显示），其次用当前歌曲在库里
  /// 扫描到的时长兜底。
  Duration get duration {
    if (_isLoaded) {
      final d = _engine.duration;
      if (d != null && d > Duration.zero) return d;
    }
    // 续播关闭时跳过上次保存的时长（避免显示上次歌曲的总长）；
    // 总时长仍由当前歌曲在库里的扫描时长兜底，不丢失。
    if (_resumePlaybackEnabled) {
      final saved = _playQueue.duration;
      if (saved > Duration.zero) return saved;
    }
    final ms = currentSong?.durationMs;
    if (ms != null && ms > 0) return Duration(milliseconds: ms);
    return Duration.zero;
  }

  /// Current repeat mode.
  PlayerRepeatMode get repeatMode => _repeatMode;

  /// Whether shuffle is enabled.
  bool get isShuffled => _isShuffled;

  /// 基础播放模式（单曲循环时为进入前的模式，否则为当前重复模式）。
  PlayerRepeatMode get baseRepeatMode => _repeatMode == PlayerRepeatMode.one
      ? (_preSingleRepeat ?? PlayerRepeatMode.off)
      : _repeatMode;

  /// 实际播放顺序：随机开启时为排列映射后的顺序，否则为逻辑队列。
  List<Song> get effectiveQueue {
    if (!_isShuffled) return _playQueue.songs;
    final songs = _playQueue.songs;
    return [
      for (final i in _order)
        if (i >= 0 && i < songs.length) songs[i],
    ];
  }

  /// 当前歌在实际播放顺序中的位置（随机时为排列位置，否则为逻辑下标）。
  int get effectiveIndex {
    if (!_isShuffled) return _playQueue.currentIndex;
    return _currentSlot;
  }

  /// 把实际播放顺序中的位置换算回逻辑下标（供 jumpTo/removeFromQueue 使用）。
  int logicalIndexForEffective(int effectiveIndex) {
    if (!_isShuffled) return effectiveIndex;
    return (effectiveIndex >= 0 && effectiveIndex < _order.length)
        ? _order[effectiveIndex]
        : effectiveIndex;
  }

  /// 当前音量（0.0~1.0）。
  double get volume => _volume;

  /// 设置音量并应用到引擎（0.0~1.0）。
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _engine.setVolume(_volume);
    notifyListeners();
  }

  /// 相对调整音量（菜单 ⌘↑/⌘↓ 用）：按 [delta] 增减并钳制在 [0,1]。
  ///
  /// 菜单调整是离散、低频操作，调整后立即写盘到 settings.json——
  /// 否则只改引擎不落盘，重启后恢复的还是旧值（强行覆盖用户最后的设置）。
  Future<void> adjustVolume(double delta) async {
    await setVolume(_volume + delta);
    try {
      // setVolume 内部已将 _volume 钳制到 [0,1]，持久化最终值。
      await ServiceLocator.settings.setVolume(_volume);
    } catch (e) {
      AppLogger.warning('Settings', 'Failed to persist menu volume', e);
    }
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
    _loadedIndex = null;
    _rebuildOrder(keepCurrentFirst: true);
    await _loadCurrent(autoPlay: true);
  }

  /// Play a single song (replaces the queue with just this one song).
  Future<void> playFromSong(Song song) async {
    await playFromList([song], startIndex: 0);
  }

  /// Append [songs] to the end of the current queue.
  Future<void> addToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    final wasEmpty = _playQueue.isEmpty;
    final from = _playQueue.length;
    _playQueue.append(songs);
    _onSongsAppended(from, songs.length);
    if (wasEmpty) {
      _resumePosition = null;
      _loadedIndex = null;
      _playQueue.setCurrentIndex(0);
      await _loadCurrent(autoPlay: true);
    }
  }

  // ─── Playback control ──────────────────────────────────

  Future<void> play() async {
    if (_playQueue.isEmpty) return;
    // 惰性加载：启动恢复的队列尚未交给引擎（macOS 沙箱时序）。
    if (!_isLoaded) {
      await _loadCurrent(autoPlay: true);
      return;
    }
    _shouldPlay = true;
    await _engine.play();
  }

  Future<void> pause() async {
    _shouldPlay = false;
    await _engine.pause();
    // 暂停是最常见的"离开播放"动作，立即落盘当前位置。
    _persistPosition();
  }

  Future<void> togglePlay() async {
    if (_engine.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    _shouldPlay = false;
    _loadedIndex = null;
    _resumePosition = null;
    await _engine.release();
    _playQueue.clear();
    _order = [];
  }

  /// 停止播放但保留队列与当前曲目（菜单「停止」⌘. 用）。
  ///
  /// 与 [stop]（停止并清空队列）不同：这里只停引擎、保留队列与当前曲目，
  /// 并把播放位置归零——再点播放会从当前曲目**开头**继续。
  ///
  /// 重构前需要 4 步 hack 才能实现（just_audio 的 `stop()` 会保留位置，下次
  /// `play()` 从原处恢复，因此必须把"序列标记未加载 + 续播位置置零 + 保存进度
  /// 清零"叠加起来）；现在引擎的 [AudioEngine.release] 语义天然匹配。
  Future<void> stopPlayback() async {
    _shouldPlay = false;
    _loadedIndex = null;
    _resumePosition = Duration.zero;
    await _engine.release();
    _playQueue.setPlaybackState(Duration.zero, Duration.zero);
    notifyListeners();
  }

  /// Skip to the next song.  Wraps around if [repeatMode] is [PlayerRepeatMode.all].
  Future<void> next() async {
    if (_playQueue.isEmpty) return;
    final slot = _currentSlot;
    if (slot + 1 < _order.length) {
      await _skipToSlot(slot + 1);
      return;
    }
    if (_repeatMode == PlayerRepeatMode.all) {
      // 一轮播完：随机时重洗排列。
      if (_isShuffled) _rebuildOrder();
      await _skipToSlot(0);
    }
    // If repeatMode is `off`, just let playback stop naturally.
  }

  /// Go back to the previous song.
  Future<void> previous() async {
    if (_playQueue.isEmpty) return;
    // If more than 3 seconds in, restart the current song.
    if (_isLoaded && _engine.position.inSeconds > 3) {
      await _engine.seek(Duration.zero);
      return;
    }
    final slot = _currentSlot;
    if (slot > 0) {
      await _skipToSlot(slot - 1);
    } else if (_repeatMode == PlayerRepeatMode.all) {
      await _skipToSlot(_order.length - 1);
    }
  }

  Future<void> seek(Duration position) async {
    // 未加载（如启动恢复队列后尚未播放）时**不能**透到引擎：audioplayers 在没有
    // source 时的 seek 会一直等到 onSeekComplete 超时。这里把它记成"待应用的
    // 播放位置"，首次加载时生效——这是用户主动拖动进度条，因此与续播开关无关。
    if (!_isLoaded) {
      _resumePosition = position;
      _playQueue.setPlaybackState(position, duration);
      notifyListeners();
      return;
    }
    await _engine.seek(position);
  }

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

  void cyclePlayMode() {
    final base = _repeatMode == PlayerRepeatMode.one
        ? (_preSingleRepeat ?? PlayerRepeatMode.off)
        : _repeatMode;
    switch ((base, _isShuffled)) {
      case (PlayerRepeatMode.off, false):
        _repeatMode = PlayerRepeatMode.all;
        _isShuffled = false;
      case (PlayerRepeatMode.all, false):
        _repeatMode = PlayerRepeatMode.all;
        _isShuffled = true;
      default:
        // (all, 随机) 或异常组合 → 回到顺序播放。
        _repeatMode = PlayerRepeatMode.off;
        _isShuffled = false;
    }
    _preSingleRepeat = null;
    _afterModeChanged();
  }

  /// 切换单曲循环：开启进入 (one)，保留随机状态；关闭恢复到进入前的基础模式。
  void toggleSingleRepeat() {
    if (_repeatMode == PlayerRepeatMode.one) {
      _repeatMode = _preSingleRepeat ?? PlayerRepeatMode.off;
      _preSingleRepeat = null;
    } else {
      _preSingleRepeat = _repeatMode;
      _repeatMode = PlayerRepeatMode.one;
    }
    _afterModeChanged();
  }

  /// 直接设置播放模式（菜单「播放模式」子菜单用）：一步到位设基础模式 + 随机开关。
  ///
  /// 与 [cyclePlayMode] 的三态循环不同，这里精确到具体状态；同时清掉单曲循环记忆
  /// （从单曲循环切到基础模式时不再恢复原模式）。
  void setPlayMode(PlayerRepeatMode mode, {required bool shuffled}) {
    _repeatMode = mode;
    _isShuffled = shuffled;
    _preSingleRepeat = null;
    _afterModeChanged();
  }

  /// 模式变更后的统一收尾：落盘 + 重建顺序表 + 同步引擎循环设置。
  void _afterModeChanged() {
    _persistModes();
    // 随机开关变化 → 重建顺序表；当前曲目保持在首位（正在播的继续播）。
    _rebuildOrder(keepCurrentFirst: true);
    unawaited(_engine.setLoopSingle(_repeatMode == PlayerRepeatMode.one));
    notifyListeners();
  }

  /// 把当前播放模式（重复 + 随机）持久化到 [PlayQueue]。
  void _persistModes() {
    _playQueue.setRepeatModeName(_repeatMode.name);
    _playQueue.setIsShuffled(_isShuffled);
  }

  // ─── Queue editing ─────────────────────────────────────

  /// Remove a song from the queue at [index].
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _playQueue.length) return;
    // 用播放意图而非引擎瞬时状态：删掉正在播放的曲目后是否继续播，取决于用户
    // 此前的意图（引擎此刻可能正处于换源的空档）。
    final wasPlaying = _shouldPlay;
    final removedCurrent = index == _playQueue.currentIndex;
    _playQueue.removeAt(index);
    _onSongRemoved(index);
    if (_playQueue.isEmpty) {
      _loadedIndex = null;
      await _engine.release();
      return;
    }
    if (removedCurrent) {
      // 删掉的是正在播放的曲目：索引已由 PlayQueue 修正，重新加载新的当前曲。
      _loadedIndex = null;
      _resumePosition = null;
      await _loadCurrent(autoPlay: wasPlaying);
    }
    // 删除其它歌曲对引擎零操作 —— 这正是"没有镜像队列"的收益。
  }

  /// Jump to the song at [index] and play.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _playQueue.length) return;
    _playQueue.setCurrentIndex(index);
    _resumePosition = null;
    _loadedIndex = null;
    await _loadCurrent(autoPlay: true);
  }

  /// Insert [songs] right after the currently playing song.
  Future<void> playNext(List<Song> songs) async {
    if (songs.isEmpty) return;
    if (_playQueue.isEmpty) {
      await playFromList(songs, startIndex: 0);
      return;
    }
    _playQueue.insertAfterCurrent(songs);
    _onSongsInsertedAfterCurrent(songs.length);
    // 引擎无需任何操作：下一首由 [_onCompleted] 的顺序推进自然取到。
  }

  /// Move a song from [oldIndex] to [newIndex] (drag-to-reorder).
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _playQueue.length ||
        newIndex < 0 ||
        newIndex >= _playQueue.length ||
        oldIndex == newIndex) {
      return;
    }
    _playQueue.move(oldIndex, newIndex);
    _onSongMoved(oldIndex, newIndex);
    // 引擎无需任何操作（播放哪一首由顺序表决定，不依赖引擎侧顺序）。
  }

  /// Clear the entire queue and stop playback.
  Future<void> clearQueue() async {
    _shouldPlay = false;
    _playQueue.clear();
    _order = [];
    _loadedIndex = null;
    _resumePosition = null;
    await _engine.release();
  }

  /// Sync the queue & audio with the library: removes any song whose
  /// `filePath` is not in [validFilePaths] (e.g. its folder was removed or
  /// the file went missing).
  ///
  /// 只有当**正在播放的曲目确实被剪掉**时才重新加载引擎——常规的库刷新
  /// （无实际变更、或只删掉了别的歌）不会打断当前播放。
  Future<void> pruneQueue(Set<String> validFilePaths) async {
    final wasPlaying = _shouldPlay;
    final pruned = _playQueue.pruneTo(validFilePaths);

    if (_playQueue.isEmpty) {
      _order = [];
      _loadedIndex = null;
      await _engine.release();
      return;
    }
    if (!pruned) return;

    _rebuildOrder(keepCurrentFirst: true);
    if (!_isLoaded) return;
    if (_engine.loadedPath == _playQueue.currentSong?.filePath) {
      // 当前曲目仍在播放：只需同步索引（顺序表已重建）。
      _loadedIndex = _playQueue.currentIndex;
      return;
    }
    // 正在播放的曲目已被剪掉 → 重新加载新的当前曲。
    _loadedIndex = null;
    _resumePosition = null;
    await _loadCurrent(autoPlay: wasPlaying);
  }

  /// 把应用状态重新对齐到引擎的真实状态。
  ///
  /// 引擎不再持有队列索引，"对账"已无对象；保留该方法以维持对外契约
  /// （打开播放页时调用），语义退化为"通知 UI 重新读取状态"。
  void resyncFromAudio() {
    notifyListeners();
  }

  // ─── Error handling ────────────────────────────────────

  /// 记录一次播放失败:更新错误消息与连续失败计数。
  ///
  /// 自动跳转由 [_skipOnFailure] 驱动;错误消息由 UI 通过
  /// [takePlaybackError] 消费并提示。
  void _reportPlaybackError(String where, Object e, StackTrace? s) {
    _consecutiveErrors++;
    final title = _playQueue.currentSong?.title;
    _lastPlaybackError = '无法播放${title != null ? '：$title' : '该文件'}，已自动跳过';
    AppLogger.error('Player', 'Playback failed in $where', e, s);
    notifyListeners();
  }

  /// 播放成功后清除失败状态(连续计数归零、错误消息清空)。
  void _clearPlaybackError() {
    _consecutiveErrors = 0;
    _failingPath = null;
    if (_lastPlaybackError != null) {
      _lastPlaybackError = null;
      notifyListeners();
    }
  }

  /// 播放失败后自动跳到下一首,但连续失败达到上限即停止。
  ///
  /// 延迟 600ms 让错误 SnackBar 先展示；若这期间用户已经手动切歌（或队列已变），
  /// 则放弃这次自动跳转——否则迟到的跳过会把用户刚选的歌顶掉。
  Future<void> _skipOnFailure(String? failedPath) async {
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
    if (failedPath != null && _playQueue.currentSong?.filePath != failedPath) {
      return;
    }
    await next();
  }

  /// 持久化当前歌曲的播放位置与总时长（供启动续播）。
  ///
  /// 仅在已加载且时长已知时落盘——避免引擎在未加载/时长未解析时用
  /// 0 或 null 覆盖已恢复的播放位置。
  void _persistPosition() {
    if (!_isLoaded) return;
    final dur = _engine.duration;
    if (dur == null || dur <= Duration.zero) return;
    _playQueue.setPlaybackState(_engine.position, dur);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completionSub?.cancel();
    _errorSub?.cancel();
    _positionSaveTimer?.cancel();
    _notifyFlushTimer?.cancel();
    unawaited(_engine.dispose());
    // 通知器最后释放：cancel 订阅后 _onQueueChanged/_onPlayingChanged 不会再
    // 被触发，避免在已 dispose 的 ValueNotifier 上写入。
    currentSongNotifier.dispose();
    playingNotifier.dispose();
    super.dispose();
  }
}
