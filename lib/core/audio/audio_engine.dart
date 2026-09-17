import 'dart:async';

/// 引擎无关的播放错误。
///
/// 各引擎的原生异常（`PlayerException` / `PlatformException` / …）在适配器内部
/// 统一转换成该类型，`PlayerService` 因此不必了解任何引擎细节。
class AudioEngineError {
  const AudioEngineError(this.message, {this.operation, this.cause});

  /// 面向日志的简短描述。
  final String message;

  /// 出错的操作（`load` / `play` / `seek` / `release` / `event`）。
  final String? operation;

  /// 原始异常（仅用于日志）。
  final Object? cause;

  @override
  String toString() =>
      'AudioEngineError(${operation ?? '-'}): $message'
      '${cause != null ? ' — $cause' : ''}';
}

/// 单曲播放引擎抽象。
///
/// 设计要点（见 `docs/AudioEngine-Migration.md` §4）：
///
/// * **刻意不含队列**：队列（顺序、索引、随机排列、重复模式、队尾收尾）全部由
///   `PlayQueue` / `PlayerService` 负责。引擎只负责"播放一个文件"，这正是消除
///   "引擎镜像队列"的结构性前提。
/// * **实现不得抛异常**：所有失败一律经 [errorStream] 上报，使调用方只有一条
///   错误处理路径。（调用方仍可防御性 try/catch，但不应依赖。）
/// * **实现必须可多实例化**：构造函数无副作用、[dispose] 干净。将来若要做
///   "双实例预加载"，只需新增一个组合式实现，接口与 `PlayerService` 都不必改。
/// * **性能约定**：[positionStream] 的刷新频率为 ~200ms 量级，**不得每帧触发**
///   （`PlayerService` 的高频 UI 与该流绑定）。
/// * **沙箱约定**：`macOS` 的 security-scoped bookmark 恢复前访问文件会失败，
///   因此 [load] 只能在用户播放动作之后调用（启动阶段不得预加载）。
abstract class AudioEngine {
  /// 当前已加载的文件路径；`null` 表示尚未加载（此时 [play] / [seek] 为 no-op）。
  String? get loadedPath;

  /// 是否正在播放。
  bool get isPlaying;

  /// 当前位置；未加载时返回 [Duration.zero]。
  Duration get position;

  /// 已加载文件的总时长；尚未解析出来时为 `null`。
  Duration? get duration;

  /// 加载 [path] 并（可选）定位到 [initialPosition]（用于续播）。
  ///
  /// 加载不同文件会替换当前 source，调用方无需先 [release]。
  /// 加载失败时 `loadedPath` 保持 `null`，错误经 [errorStream] 上报。
  Future<void> load(String path, {Duration? initialPosition});

  /// 开始/继续播放（[loadedPath] 为 `null` 时 no-op）。
  ///
  /// ⚠️ 实现必须**立即返回**：某些引擎的 `play()` 会一直等到“暂停/播完”才 complete，
  /// 直接 await 会阻塞调用方（队列推进、UI）。
  Future<void> play();

  Future<void> pause();

  /// 停止并释放资源；之后必须重新 [load] 才能播放。
  ///
  /// 调用后 `loadedPath` 变为 `null`、[position] 归零。
  Future<void> release();

  /// 跳转到 [position]。**未加载时必须是安全的 no-op**。
  ///
  /// ⚠️ `audioplayers` 的 `seek()` 会等待 `onSeekComplete` 事件（30s 超时），而
  /// 其 darwin 实现在没有 currentItem 时直接返回、**不发送该事件** —— 因此守卫
  /// 必须落在适配器内部，不能让未加载状态下的 seek 透到引擎。
  Future<void> seek(Duration position);

  /// 设置音量（0.0~1.0）。应记住该值并在重新 [load] 后保持有效。
  Future<void> setVolume(double volume);

  /// 单曲循环（对应 `RepeatMode.one`）。
  ///
  /// 允许实现用原生循环能力（无间隙）；此时**完成事件是否上报因引擎而异**
  /// （`audioplayers` 的 `ReleaseMode.loop` 仍会上报），调用方需按重复模式自行
  /// 忽略完成事件。
  Future<void> setLoopSingle(bool loop);

  /// 播放进度（~200ms 量级）。
  Stream<Duration> get positionStream;

  /// 时长变化（加载后可解析出时上报）。
  Stream<Duration?> get durationStream;

  /// 播放/暂停状态翻转。
  Stream<bool> get playingStream;

  /// 单曲**自然播完**（切歌 / 暂停 / 释放**不会**触发）。
  Stream<void> get completionStream;

  /// 加载 / 播放 / 跳转失败。
  Stream<AudioEngineError> get errorStream;

  /// 释放引擎实例。调用后该实例不可再用。
  Future<void> dispose();
}
