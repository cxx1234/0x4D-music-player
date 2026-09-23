import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../utils/keyboard_focus.dart';
import '../utils/logger.dart';
import 'playback_feedback_service.dart';
import 'player_service.dart';
import 'sleep_timer_service.dart';

/// 桥接 macOS 原生菜单（`AppDelegate.swift`）与播放器 / 导航。
///
/// 职责：
/// - 把播放状态（是否有曲目 / 播放中 / 随机 / 循环 / 文本编辑中 / 有键盘聚焦
///   控件 / 睡眠定时）推给原生，驱动菜单项使能、标题（播放↔暂停）、勾选态
///   （单曲循环、播放模式三选一、睡眠定时）；
/// - 接收原生菜单动作（播放·暂停 / 上一首 / 下一首 / 单曲循环 / 播放模式 /
///   睡眠定时 / 打开设置），转发给 [PlayerService] 或 [openSettings] 回调。
///
/// 仅 macOS 生效（其他平台无原生菜单通道，不创建实例，避免通道噪音）。
class MenuService {
  MenuService._(this._player, this._feedback, this._sleepTimer);

  static const _channel = MethodChannel('com.jerryc.txvziwm/menu');

  final PlayerService _player;

  /// 播放类动作经它转发：原生菜单与媒体键共享同一套 HUD / 控件脉冲反馈。
  final PlaybackFeedbackService _feedback;

  /// 只读它的状态（推给原生打勾）；动作仍经 [_feedback] 执行。
  final SleepTimerService _sleepTimer;

  /// 菜单「偏好设置…」(⌘,) 动作回调（由 App 注入：切到设置 tab）。
  void Function()? openSettings;

  /// 菜单「关于本软件」动作回调（由 App 注入：切到设置 tab 并打开关于页）。
  void Function()? openAbout;

  /// 菜单「新建播放列表…」(⌘N) 动作回调（由 App 注入：切到播放列表 tab）。
  void Function()? openPlaylists;

  /// 菜单「导入文件夹…」(⌘O) 动作回调（由 App 注入：切到音乐库 tab）。
  void Function()? openLibrary;

  /// 菜单「导入播放列表…」动作回调（由 App 注入：切到播放列表 tab）。
  void Function()? openImportPlaylist;

  /// 菜单「导出播放列表…」动作回调（由 App 注入：切到播放列表 tab）。
  void Function()? openExportPlaylist;

  /// 上次推送的状态快照（去重：播放进度每 ~200ms notify，不能每次都推通道）。
  ({
    bool hasTrack,
    bool isPlaying,
    bool isShuffled,
    String repeatMode,
    bool isTextEditing,
    bool hasKeyboardFocus,
    String sleepTimerMode,
    int sleepTimerMinutes,
  })?
  _lastPushed;

  /// 焦点相关结论的缓存：只在 Focus 变化时算一次（[FocusManager] 的监听），
  /// 不在每次 `_push()`（含每 ~200ms 的播放进度通知）里做 UI 树祖先遍历。
  bool _isTextEditing = false;
  bool _hasKeyboardFocus = false;

  bool _attached = false;
  bool _disposed = false;

  /// 创建实例并注册通道 handler + 播放器 / 焦点 / 睡眠定时监听。
  factory MenuService.attach(
    PlayerService player,
    PlaybackFeedbackService feedback,
    SleepTimerService sleepTimer,
  ) {
    final service = MenuService._(player, feedback, sleepTimer);
    service._init();
    return service;
  }

  void _init() {
    _channel.setMethodCallHandler(_handleCall);
    _attached = true;
    _player.addListener(_onPlayerChanged);
    _sleepTimer.state.addListener(_onPlayerChanged);
    _refreshFocusFlags();
    _push();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  Future<Object?> _handleCall(MethodCall call) async {
    if (call.method != 'menuAction') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final action = args['action'];
    if (action is! String) return null;
    switch (action) {
      case 'playPause':
        await _feedback.togglePlay();
      case 'previous':
        await _feedback.previous();
      case 'next':
        await _feedback.next();
      case 'stop':
        await _feedback.stop();
      case 'volumeUp':
        await _feedback.adjustVolume(0.1);
      case 'volumeDown':
        await _feedback.adjustVolume(-0.1);
      case 'toggleSingleRepeat':
        _player.toggleSingleRepeat();
      case 'setPlayMode':
        _applySetPlayMode(args['value']);
      case 'sleepTimer':
        _applySleepTimer(args['value']);
      case 'openSettings':
        openSettings?.call();
      case 'openAbout':
        openAbout?.call();
      case 'newPlaylist':
        openPlaylists?.call();
      case 'importFolder':
        openLibrary?.call();
      case 'importPlaylist':
        openImportPlaylist?.call();
      case 'exportPlaylist':
        openExportPlaylist?.call();
    }
    return null;
  }

  void _applySetPlayMode(Object? value) {
    switch (value) {
      case 'sequential':
        _player.setPlayMode(PlayerRepeatMode.off, shuffled: false);
      case 'repeatAll':
        _player.setPlayMode(PlayerRepeatMode.all, shuffled: false);
      case 'shuffleAll':
        _player.setPlayMode(PlayerRepeatMode.all, shuffled: true);
    }
  }

  /// 原生菜单「睡眠定时」子菜单：预设分钟项用 `NSMenuItem.tag` 传分钟数（通道里
  /// 是 int），两个"播完…"与取消项用 `representedObject` 传字符串。
  void _applySleepTimer(Object? value) {
    switch (value) {
      case 'endOfTrack':
        _feedback.startSleepTimerAtEnd(atQueueEnd: false);
      case 'endOfQueue':
        _feedback.startSleepTimerAtEnd(atQueueEnd: true);
      case 'cancel':
        _feedback.cancelSleepTimer();
      default:
        final minutes = value is num ? value.toInt() : int.tryParse('$value');
        if (minutes != null && minutes > 0) {
          _feedback.startSleepTimer(minutes);
        }
    }
  }

  void _onPlayerChanged() => _push();

  void _onFocusChanged() {
    _refreshFocusFlags();
    _push();
  }

  /// 重算焦点相关结论（只在 Focus 变化时调用，见字段注释）。
  void _refreshFocusFlags() {
    final focus = FocusManager.instance.primaryFocus;
    _hasKeyboardFocus = hasKeyboardFocus;
    _isTextEditing =
        focus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _push() {
    if (_disposed || !_attached) return;
    // 睡眠定时：只推"模式 + 当初设定的分钟数"（倒计时每秒都在变，但那不参与
    // 去重比较，所以不会每秒推一次通道）。
    final timerState = _sleepTimer.state.value;
    final state = (
      hasTrack: _player.currentSong != null,
      isPlaying: _player.isPlaying,
      isShuffled: _player.isShuffled,
      repeatMode: _player.repeatMode.name,
      isTextEditing: _isTextEditing,
      hasKeyboardFocus: _hasKeyboardFocus,
      sleepTimerMode: timerState?.mode.name ?? 'off',
      sleepTimerMinutes: timerState?.requested?.inMinutes ?? 0,
    );
    final last = _lastPushed;
    if (last != null &&
        last.hasTrack == state.hasTrack &&
        last.isPlaying == state.isPlaying &&
        last.isShuffled == state.isShuffled &&
        last.repeatMode == state.repeatMode &&
        last.isTextEditing == state.isTextEditing &&
        last.hasKeyboardFocus == state.hasKeyboardFocus &&
        last.sleepTimerMode == state.sleepTimerMode &&
        last.sleepTimerMinutes == state.sleepTimerMinutes) {
      return;
    }
    _lastPushed = state;
    unawaited(
      _channel
          .invokeMethod<void>('updateMenuState', {
            'hasTrack': state.hasTrack,
            'isPlaying': state.isPlaying,
            'isShuffled': state.isShuffled,
            'repeatMode': state.repeatMode,
            'isTextEditing': state.isTextEditing,
            'hasKeyboardFocus': state.hasKeyboardFocus,
            'sleepTimerMode': state.sleepTimerMode,
            'sleepTimerMinutes': state.sleepTimerMinutes,
          })
          .catchError((Object e) {
            AppLogger.warning('Menu', 'Failed to push menu state', e);
          }),
    );
  }

  void dispose() {
    _disposed = true;
    if (_attached) {
      _player.removeListener(_onPlayerChanged);
      _sleepTimer.state.removeListener(_onPlayerChanged);
      FocusManager.instance.removeListener(_onFocusChanged);
    }
  }
}
