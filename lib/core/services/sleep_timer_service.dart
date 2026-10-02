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
  const SleepTimerState({
    required this.mode,
    this.remaining,
    this.requested,
    this.fading = false,
  });

  final SleepTimerMode mode;

  /// 剩余时长——仅 [SleepTimerMode.duration] 有值。
  final Duration? remaining;

  /// 本次倒计时**一开始设定**的总时长（不随归零变化）。
  ///
  /// 给"需要知道当初选了多久"的地方用（如 macOS 原生菜单勾选对应的预设项）；
  /// 归零过程中的实时进度看 [remaining]。
  final Duration? requested;

  /// 倒计时已归零、正在淡出（音量渐降的那几秒）。
  ///
  /// 淡出期间状态**必须保持激活**：否则取消入口（播放条按钮的「取消定时」、
  /// 原生菜单项）会在这几秒里消失，用户再也无法中断。
  final bool fading;

  SleepTimerState withRemaining(Duration value) => SleepTimerState(
    mode: mode,
    remaining: value,
    requested: requested,
    fading: fading,
  );

  /// 切换到「正在淡出」（剩余归零、保留 [requested] 供菜单勾选）。
  SleepTimerState withFading() => SleepTimerState(
    mode: mode,
    remaining: Duration.zero,
    requested: requested,
    fading: true,
  );

  @override
  bool operator ==(Object other) =>
      other is SleepTimerState &&
      other.mode == mode &&
      other.remaining == remaining &&
      other.requested == requested &&
      other.fading == fading;

  @override
  int get hashCode => Object.hash(mode, remaining, requested, fading);
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

  /// 倒计时截止时刻。剩余时长按它算，而不是「每次 tick 减一个步长」——
  /// 后者在定时器被节流 / 系统睡眠时会凭空多出时间（醒来仍显示原剩余分钟数），
  /// 且每次 tick 的调度误差会持续累积。
  DateTime? _deadline;

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
    _deadline = DateTime.now().add(duration);
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
  ///
  /// 到点淡出期间同样可调用：此刻状态仍是激活的（[SleepTimerState.fading]），
  /// 这里会立即中止淡出并把引擎音量还原成用户音量。
  void cancel() {
    final wasActive = isActive;
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    state.value = null;
    // 不能放在上面的早退之后：淡出期间即使状态已被别处清掉，这一步也必须执行
    // （`cancelFadeOut` 自身对「没有淡出在跑」是 no-op）。
    _player.cancelFadeOut();
    if (wasActive) AppLogger.info('Player', 'Sleep timer cancelled');
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
    _deadline = null;
    state.value = SleepTimerState(mode: mode);
    AppLogger.info('Player', 'Sleep timer started: ${mode.name}');
  }

  void _onTick(Timer timer) {
    final current = state.value;
    final deadline = _deadline;
    // 状态被外部清掉（取消）却漏了取消计时器 → 兜底自杀。
    if (current == null || deadline == null) {
      timer.cancel();
      _timer = null;
      return;
    }
    final remaining = deadline.difference(DateTime.now());
    if (remaining > Duration.zero) {
      state.value = current.withRemaining(remaining);
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
    // 淡出期间**保持激活**（fading 标志）：让「取消定时」入口留到最后一刻。
    // 提示也等淡出真正结束再发——否则「已暂停」与还能听见的这几秒不符。
    final current = state.value;
    if (current != null) state.value = current.withFading();
    await _player.fadeOutAndPause(duration: fadeDuration);
    if (_disposed) return;
    // 淡出期间被取消（`cancel()` 已清状态）或被「用户重新起播」接管
    // （见 [_onPlayerChanged]）时，状态已为空 —— 不要在这里谎报「已暂停」。
    if (state.value?.fading != true) return;
    state.value = null;
    if (!_player.isPlaying) notice.value = '睡眠定时结束，已暂停';
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
    _deadline = null;
    state.value = null;
    notice.value = message;
    AppLogger.info('Player', 'Sleep timer fired; playback paused');
  }

  /// 播放器状态变化 → 维护睡眠定时的安全网。
  void _onPlayerChanged() {
    if (_disposed || !isActive) return;
    // 队列被清空 → 自动取消（此时"到点暂停"已无对象）。
    if (_player.queue.isEmpty) {
      cancel();
      return;
    }
    // 淡出期间用户又起播（如媒体键 Play）→ 视为放弃本次定时：PlayerService 已
    // 中止淡出并还原音量，这里只需把状态收回，避免几秒后弹一次「已暂停」。
    if ((state.value?.fading ?? false) && _player.isPlaying) {
      state.value = null;
      _deadline = null;
      AppLogger.info('Player', 'Sleep timer fade-out cancelled by user');
    }
  }

  /// 日志用的时长描述（不足 1 分钟时说秒，免得打成 "0min"）。
  static String _describe(Duration duration) => duration.inMinutes >= 1
      ? '${duration.inMinutes}min'
      : '${duration.inSeconds}s';
}
