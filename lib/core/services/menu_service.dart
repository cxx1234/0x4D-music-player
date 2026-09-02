import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../utils/logger.dart';
import 'player_service.dart';

/// 桥接 macOS 原生菜单（`AppDelegate.swift`）与播放器 / 导航。
///
/// 职责：
/// - 把播放状态（是否有曲目 / 播放中 / 随机 / 循环 / 文本编辑中）推给原生，
///   驱动菜单项使能、标题（播放↔暂停）、勾选态（单曲循环、播放模式三选一）；
/// - 接收原生菜单动作（播放·暂停 / 上一首 / 下一首 / 单曲循环 / 播放模式 /
///   打开设置），转发给 [PlayerService] 或 [openSettings] 回调。
///
/// 仅 macOS 生效（其他平台无原生菜单通道，不创建实例，避免通道噪音）。
class MenuService {
  MenuService._(this._player);

  static const _channel = MethodChannel('flutter_music/menu');

  final PlayerService _player;

  /// 菜单「偏好设置…」(⌘,) 动作回调（由 App 注入：切到设置 tab）。
  void Function()? openSettings;

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
  })?
  _lastPushed;

  bool _attached = false;
  bool _disposed = false;

  /// 创建实例并注册通道 handler + 播放器 / 焦点监听。
  factory MenuService.attach(PlayerService player) {
    final service = MenuService._(player);
    service._init();
    return service;
  }

  void _init() {
    _channel.setMethodCallHandler(_handleCall);
    _attached = true;
    _player.addListener(_onPlayerChanged);
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
        await _player.togglePlay();
      case 'previous':
        await _player.previous();
      case 'next':
        await _player.next();
      case 'stop':
        await _player.stopPlayback();
      case 'volumeUp':
        await _player.adjustVolume(0.1);
      case 'volumeDown':
        await _player.adjustVolume(-0.1);
      case 'toggleSingleRepeat':
        _player.toggleSingleRepeat();
      case 'setPlayMode':
        _applySetPlayMode(args['value']);
      case 'openSettings':
        openSettings?.call();
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

  void _onPlayerChanged() => _push();

  void _onFocusChanged() => _push();

  /// 是否正处于文本编辑（Flutter 文本框聚焦）——原生据此让空格/⌘←/⌘→
  /// 菜单键等价放行给文本框。
  bool _isTextEditing() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null) return false;
    return focus.context!.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _push() {
    if (_disposed || !_attached) return;
    final state = (
      hasTrack: _player.currentSong != null,
      isPlaying: _player.isPlaying,
      isShuffled: _player.isShuffled,
      repeatMode: _player.repeatMode.name,
      isTextEditing: _isTextEditing(),
    );
    final last = _lastPushed;
    if (last != null &&
        last.hasTrack == state.hasTrack &&
        last.isPlaying == state.isPlaying &&
        last.isShuffled == state.isShuffled &&
        last.repeatMode == state.repeatMode &&
        last.isTextEditing == state.isTextEditing) {
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
      FocusManager.instance.removeListener(_onFocusChanged);
    }
  }
}
