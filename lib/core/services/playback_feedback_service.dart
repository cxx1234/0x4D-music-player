import 'package:flutter/material.dart';

import 'hud_service.dart';
import 'player_service.dart';

/// 需要「控件脉冲」反馈的外部播放操作。
enum PlaybackAction { playPause, previous, next }

/// 一次外部操作脉冲。
///
/// [seq] 自增：`ValueNotifier` 对相同值不会通知，而连续两次"下一首"必须都触发
/// 按钮脉冲，所以负载必须每次都是新对象。
@immutable
class PlaybackPulse {
  const PlaybackPulse({required this.seq, required this.action});

  final int seq;
  final PlaybackAction action;
}

/// 外部播放入口（macOS 原生菜单 / 媒体键 / 系统「正在播放」面板）的统一出口。
///
/// 为什么要有它：这些入口**在界面上没有对应控件**，用户按下去之后只能自己听/
/// 看播放器状态。统一出口让两条入口共享同一套反馈：
/// - [pulses]：控件脉冲 —— 播放页与底栏的对应按钮亮一下（播放页没有 HUD，
///   只有它能给出反馈）；
/// - [HudService]：底部浮动提示 —— 其他页面上只有它看得见。
///
/// 文案集中在这里：本仓库没有 i18n，两个入口必须说同一句话，分开写迟早会跑偏。
///
/// ⚠️ 范围刻意只有 音量 / 切歌 / 播放暂停 / 停止：循环模式、随机、列表内的动作都
/// 已有可见的 UI 状态，再叠一层提示只是噪音。
class PlaybackFeedbackService {
  PlaybackFeedbackService(this._player, this._hud);

  final PlayerService _player;
  final HudService _hud;

  int _seq = 0;

  /// 供 UI 订阅的脉冲流（值本身不重要，收到即表示"该亮一下了"）。
  final ValueNotifier<PlaybackPulse?> pulses = ValueNotifier<PlaybackPulse?>(
    null,
  );

  /// 播放 / 暂停（菜单 ⌘P、媒体键 Toggle）。
  Future<void> togglePlay() async {
    await _player.togglePlay();
    _afterPlayStateChange();
  }

  /// 显式播放（媒体键 Play / 系统「正在播放」面板）。
  Future<void> play() async {
    await _player.play();
    _afterPlayStateChange();
  }

  /// 显式暂停（媒体键 Pause）。
  Future<void> pause() async {
    await _player.pause();
    _afterPlayStateChange();
  }

  /// 播放态变化后的统一反馈：按钮脉冲 + HUD 结果文案。
  ///
  /// 文案用**结果态**（播放中 / 已暂停）而不是动作名，避免"按暂停后显示暂停"
  /// 与"当前已暂停"两种读法混淆。
  void _afterPlayStateChange() {
    final playing = _player.isPlaying;
    _emit(PlaybackAction.playPause);
    _hud.show(
      HudMessage(
        icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        text: playing ? '播放中' : '已暂停',
        kind: HudKind.playback,
      ),
    );
  }

  /// 上一首（菜单、媒体键）。队首且不循环时提示「已是第一首」。
  Future<void> previous() async {
    final beforeIndex = _player.currentIndex;
    final beforeId = _player.currentSong?.id;
    await _player.previous();
    _emit(PlaybackAction.previous);
    _showTrackAfterMove(
      label: '上一首',
      icon: Icons.skip_previous_rounded,
      beforeIndex: beforeIndex,
      beforeId: beforeId,
      emptyQueueText: '已是第一首',
    );
  }

  /// 下一首（菜单、媒体键）。队尾且不循环时提示「已是最后一首」。
  Future<void> next() async {
    final beforeIndex = _player.currentIndex;
    final beforeId = _player.currentSong?.id;
    await _player.next();
    _emit(PlaybackAction.next);
    _showTrackAfterMove(
      label: '下一首',
      icon: Icons.skip_next_rounded,
      beforeIndex: beforeIndex,
      beforeId: beforeId,
      emptyQueueText: '已是最后一首',
    );
  }

  /// 停止（菜单 ⌘.）。停止会清空队列，底栏随即变成「未在播放」。
  ///
  /// 只发 HUD、**不发控件脉冲**：应用里没有「停止」按钮可点亮（原生菜单项
  /// 自己会高亮），HUD 是唯一反馈。
  Future<void> stop() async {
    await _player.stopPlayback();
    _hud.show(
      const HudMessage(
        icon: Icons.stop_rounded,
        text: '已停止',
        kind: HudKind.playback,
      ),
    );
  }

  /// 相对调整音量（菜单 ⌘↑/⌘↓）。落盘在 [PlayerService.adjustVolume] 内完成。
  ///
  /// 不发脉冲：播放页的音量滑块本身会跟着动，不需要额外高亮。
  Future<void> adjustVolume(double delta) async {
    await _player.adjustVolume(delta);
    final volume = _player.volume;
    _hud.show(
      HudMessage(
        icon: volume <= 0
            ? Icons.volume_off_rounded
            : (volume < 0.5
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded),
        text: '${(volume * 100).round()}%',
        kind: HudKind.volume,
      ),
    );
  }

  /// 切歌后的提示：真的换歌了显示「下一首 · 歌名」，否则说明为什么没动。
  ///
  /// 判定用「动作前后是否变化」为主（索引 + 歌曲 id 双判定：单曲队列 + 列表循环
  /// 时 id 不变但会重播，索引也会绕回同一个值），所以额外把「列表循环 → 必然
  /// 回到队首重播」也算作真的切了 —— 否则单曲循环按 ⌘→ 会误报「已是最后一首」。
  void _showTrackAfterMove({
    required String label,
    required IconData icon,
    required int beforeIndex,
    required int? beforeId,
    required String emptyQueueText,
  }) {
    final after = _player.currentSong;
    if (after == null && beforeId == null) {
      // 队列里根本没歌：⌘→ 这类按键不该被解释成"最后一首"。
      _hud.show(
        const HudMessage(
          icon: Icons.music_off_rounded,
          text: '没有播放中的歌曲',
          kind: HudKind.track,
        ),
      );
      return;
    }
    final moved = after?.id != beforeId || _player.currentIndex != beforeIndex;
    final wrapped = !moved && _player.repeatMode == PlayerRepeatMode.all;
    _hud.show(
      HudMessage(
        icon: icon,
        text: (moved || wrapped)
            ? '$label · ${after?.title ?? ''}'
            : emptyQueueText,
        kind: HudKind.track,
      ),
    );
  }

  void _emit(PlaybackAction action) {
    pulses.value = PlaybackPulse(seq: ++_seq, action: action);
  }

  void dispose() {
    pulses.dispose();
  }
}
