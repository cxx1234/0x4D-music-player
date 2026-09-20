import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/logger.dart';
import 'player_service.dart';

/// 睡眠定时的触发方式。
enum SleepTimerMode {
  /// 倒计时归零时停止（[SleepTimerState.remaining] 每秒递减）。
  duration,

  /// **播完当前曲目**时停止（不推进到下一首）。
  endOfTrack,

  /// **播完当前播放顺序（一轮）**时停止：队尾那一曲结束时停下。
  endOfQueue,
}

/// 睡眠定时状态；`null`（见 [SleepTimerService.state]）表示未激活。
@immutable
class SleepTimerState {
  const SleepTimerState({required this.mode, this.remaining, this.requested});

  final SleepTimerMode mode;

  /// 剩余时长——仅 [SleepTimerMode.duration] 有值。
  final Duration? remaining;

  /// 本次倒计时**一开始设定**的总时长（不随归零变化）。
  ///
  /// 给"需要知道当初选了多久"的地方用（如 macOS 原生菜单勾选对应的预设项）；
  /// 归零过程中的实时进度看 [remaining]。
  final Duration? requested;

  SleepTimerState withRemaining(Duration value) =>
      SleepTimerState(mode: mode, remaining: value, requested: requested);

  @override
  bool operator ==(Object other) =>
      other is SleepTimerState &&
      other.mode == mode &&
      other.remaining == remaining &&
      other.requested == requested;

  @override
  int get hashCode => Object.hash(mode, remaining, requested);
}

/// 睡眠定时：到点后**淡出并暂停**（保留队列与当前位置，再点播放能接着听）。
///
/// ### 为什么是一个独立服务
///
/// 它是**会话态**而非设置项（不落盘，重启即失效），且有两个消费者——播放条上的
/// 按钮与原生菜单——都只是它的视图。因此与 `PlayerService` 同生命周期放在
/// `ServiceLocator`，页面/菜单只订阅 [state]。
///
/// ### 与播放器的分工
///
/// * [SleepTimerMode.duration]：本类自己计时，到点调
///   [PlayerService.fadeOutAndPause]；若 [waitForTrackEnd] 为真（设置页选项），
///   到点改为转入 [SleepTimerMode.endOfTrack]——即"等这一首播完再停"。
/// * [SleepTimerMode.endOfTrack] / [SleepTimerMode.endOfQueue]：挂上
///   [PlayerService.onBeforeTrackAdvance] 钩子，在曲目自然播完、队列即将推进的
///   那一刻接管（曲目本身已静音，无需淡出），直接
///   [PlayerService.stopPlayback]。
///
/// ⚠️ 本类刻意不依赖 `ServiceLocator`（只依赖 [PlayerService]），因此可纯逻辑单测。
class SleepTimerService {
  SleepTimerService(
    this._player, {
    this.fadeDuration = PlayerService.kSleepFadeDuration,
    this.tickInterval = const Duration(seconds: 1),
    this.waitForTrackEnd,
  }) {
    _player.onBeforeTrackAdvance = _onBeforeTrackAdvance;
    // 安全网：队列被清空（停止 / 清空队列 / 删掉全部歌曲）→ 定时没有意义了。
    // 订 uiListenable 而非整个 service：后者随播放进度每 ~200ms 通知一次。
    _player.uiListenable.addListener(_onPlayerChanged);
  }

  final PlayerService _player;

  /// 到点时的淡出时长（测试传 [Duration.zero] 走即时暂停）。
  final Duration fadeDuration;

  /// 倒计时步长（测试可调小，免去等真实秒数）。
  final Duration tickInterval;

  /// 倒计时到点后是否改为「播完当前曲再停」（设置页的选项）。
  ///
  /// 刻意用回调而不是布尔字段：真值存在 `settings.json` 里，每次到点现读，
  /// 设置改了立即生效，不需要两处状态同步。null = 恒定不等待。
  final bool Function()? waitForTrackEnd;

  /// 当前状态；`null` = 未激活。UI 订阅它即可拿到剩余时长。
  final ValueNotifier<SleepTimerState?> state = ValueNotifier<SleepTimerState?>(
    null,
  );

  /// 到点提示（消费即清）：UI 订阅它在任意页面弹一次提示。
  final ValueNotifier<String?> notice = ValueNotifier<String?>(null);

  Timer? _timer;
  bool _disposed = false;

  bool get isActive => state.value != null;

  /// 剩余时长（非倒计时模式为 null）。
  Duration? get remaining => state.value?.remaining;

  /// 当前模式（未激活为 null）。
  SleepTimerMode? get mode => state.value?.mode;

  /// 倒计时 [duration] 后停止。
  void startForDuration(Duration duration) {
    if (duration <= Duration.zero) return;
    _timer?.cancel();
    state.value = SleepTimerState(
      mode: SleepTimerMode.duration,
      remaining: duration,
      requested: duration,
    );
    _timer = Timer.periodic(tickInterval, _onTick);
    AppLogger.info('Player', 'Sleep timer started: ${_describe(duration)}');
  }

  /// 播完当前曲目后停止。
  void startForEndOfTrack() => _startForMode(SleepTimerMode.endOfTrack);

  /// 播完当前播放顺序（一轮）后停止。
  void startForEndOfQueue() => _startForMode(SleepTimerMode.endOfQueue);

  /// 取消定时（未激活时为 no-op）。
  void cancel() {
    if (!isActive && _timer == null) return;
    _timer?.cancel();
    _timer = null;
    state.value = null;
    // 若正处在到点淡出中，一并中止并还原音量。
    _player.cancelFadeOut();
    AppLogger.info('Player', 'Sleep timer cancelled');
  }

  /// 消费并清除到点提示（返回 null 表示没有待提示的消息）。
  String? takeNotice() {
    final value = notice.value;
    notice.value = null;
    return value;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _player.uiListenable.removeListener(_onPlayerChanged);
    // 只有仍是自己的钩子才清空（防未来接入其它钩子时被误删）。
    if (_player.onBeforeTrackAdvance == _onBeforeTrackAdvance) {
      _player.onBeforeTrackAdvance = null;
    }
    state.dispose();
    notice.dispose();
  }

  // ─── 内部实现 ──────────────────────────────────────────

  void _startForMode(SleepTimerMode mode) {
    _timer?.cancel();
    _timer = null;
    state.value = SleepTimerState(mode: mode);
    AppLogger.info('Player', 'Sleep timer started: ${mode.name}');
  }

  void _onTick(Timer timer) {
    final current = state.value;
    // 状态被外部清掉（取消）却漏了取消计时器 → 兜底自杀。
    if (current?.remaining == null) {
      timer.cancel();
      _timer = null;
      return;
    }
    final next = current!.remaining! - tickInterval;
    if (next > Duration.zero) {
      state.value = current.withRemaining(next);
      return;
    }
    timer.cancel();
    _timer = null;
    unawaited(_stopForDuration());
  }

  /// 倒计时到点：立即收尾，或（设置开启时）转为「播完当前曲再停」。
  Future<void> _stopForDuration() async {
    // 设置开启且此刻确实在播放 → 不立即停，交给已有的曲末钩子：状态切成
    // endOfTrack 后，按钮上的剩余时间会变成"播完当前曲目"（用户看得见）。
    // 已暂停（用户自己停的）/ 没在播时不等待——否则定时会永远挂着等不到曲末。
    if ((waitForTrackEnd?.call() ?? false) && _player.isPlaying) {
      AppLogger.info(
        'Player',
        'Sleep timer expired; waiting for the current track to finish',
      );
      _startForMode(SleepTimerMode.endOfTrack);
      // 提示一次"到点了、改为等这一首播完"：否则用户只看到倒计时突然消失，
      // 会以为定时失效了（真正停下时还会再弹一条）。
      notice.value = '睡眠定时到点，播完当前曲目后停止';
      return;
    }
    _notify('睡眠定时结束，已暂停');
    await _player.fadeOutAndPause(duration: fadeDuration);
  }

  /// 曲目自然播完的接管点（见 [PlayerService.onBeforeTrackAdvance]）。
  bool _onBeforeTrackAdvance(bool isLastInOrder) {
    final current = state.value;
    if (current == null) return false;
    final takeOver =
        current.mode == SleepTimerMode.endOfTrack ||
        (current.mode == SleepTimerMode.endOfQueue && isLastInOrder);
    if (!takeOver) return false;
    _notify('睡眠定时结束，已停止播放');
    // 曲目已经自然播完（引擎此刻静音），无需淡出。用 [PlayerService.stopPlayback]
    // 而不是 pause：引擎停在"已完成"状态时，再按播放键会什么也不做（audioplayers
    // 的 resume 不会自动回到开头）；stopPlayback 释放引擎并归零，下次播放会
    // 重新加载当前曲目从头播。
    unawaited(_player.stopPlayback());
    return true;
  }

  /// 统一的"到点"收尾：清状态 + 发提示。
  void _notify(String message) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    state.value = null;
    notice.value = message;
    AppLogger.info('Player', 'Sleep timer fired; playback paused');
  }

  /// 队列被清空 → 自动取消（此时"到点暂停"已无对象）。
  void _onPlayerChanged() {
    if (_disposed || !isActive) return;
    if (_player.queue.isEmpty) cancel();
  }

  /// 日志用的时长描述（不足 1 分钟时说秒，免得打成 "0min"）。
  static String _describe(Duration duration) => duration.inMinutes >= 1
      ? '${duration.inMinutes}min'
      : '${duration.inSeconds}s';
}
