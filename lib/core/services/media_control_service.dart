import 'dart:async';

import '../audio/media_control_event.dart';
import '../audio/now_playing_info.dart';
import '../audio/platform_media_controls.dart';
import '../database/database.dart';
import '../utils/logger.dart';
import 'player_service.dart';

/// Bridges the system media controls (media keys, Control Center, lock
/// screen) and the app's [PlayerService].
///
/// Responsibilities:
/// - Push Now Playing metadata to the OS whenever playback state changes.
/// - Forward user control events coming from the OS back into the player.
///
/// This keeps [PlayerService] pure — it knows nothing about platform media
/// integration.
class MediaControlService {
  final PlayerService _player;
  final PlatformMediaControls _controls;

  StreamSubscription<MediaControlEvent>? _eventSub;
  Timer? _positionTimer;

  Song? _lastSong;
  bool _lastIsPlaying = false;

  /// 上次全量推送时的曲目时长：时长从「未知 → 已知」（新曲加载完成）时需要补
  /// 一次完整推送，否则系统 Now Playing 的 PlaybackDuration 会缺失。
  Duration _lastDuration = Duration.zero;

  /// 原生侧是否缺少 `updateElapsed`（旧二进制 / 尚未实现该通道的平台）。
  ///
  /// 首次失败后固定回退到「每秒完整推送」：既不每秒刷未处理异常，也不让功能
  /// 退化到不更新进度。
  bool _elapsedUnsupported = false;

  MediaControlService(this._player, this._controls);

  /// Registers with the system and starts listening.
  Future<void> initialize() async {
    await _controls.setup();

    _eventSub = _controls.events.listen(_handleEvent);
    _player.addListener(_onPlayerChanged);

    // Keep the lock-screen / Control Center progress bar in sync while
    // playing. PlayerService notifies on every position tick, so we throttle
    // here instead of pushing on each notification.
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_player.isPlaying) {
        // 播放中的每秒刷新走轻量通道：只更新 elapsed/rate，不重传封面。
        _pushElapsed();
      }
    });

    _pushCurrent();
  }

  void _handleEvent(MediaControlEvent event) {
    switch (event) {
      case PlayEvent():
        _player.play();
      case PauseEvent():
        _player.pause();
      case TogglePlayEvent():
        _player.togglePlay();
      case NextEvent():
        _player.next();
      case PreviousEvent():
        _player.previous();
      case SeekEvent(:final position):
        _player.seek(position);
    }
  }

  void _onPlayerChanged() {
    final song = _player.currentSong;
    final isPlaying = _player.isPlaying;
    // Skip redundant pushes (PlayerService notifies very frequently, e.g. on
    // every position tick); only song or play/pause transitions matter here.
    if (song != _lastSong || isPlaying != _lastIsPlaying) {
      _lastSong = song;
      _lastIsPlaying = isPlaying;
      _pushCurrent();
    }
  }

  /// 完整推送（含封面）：切歌 / 播放态翻转 / 时长刚解析出来时使用。
  void _pushCurrent() {
    final song = _player.currentSong;
    if (song == null) {
      _controls.clearNowPlaying();
      return;
    }
    final duration = _player.duration;
    _lastDuration = duration;
    _controls.updateNowPlaying(
      NowPlayingInfo(
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: duration,
        position: _player.position,
        isPlaying: _player.isPlaying,
        coverFilePath: song.albumArtFilePath,
      ),
    );
  }

  /// 轻量进度刷新：只更新系统 UI 的 elapsed/rate。
  ///
  /// 之前每秒都走完整推送，原生侧会为此**每秒重新读盘并解码封面**
  /// （`NSImage(contentsOfFile:)` + 重建 `MPMediaItemArtwork`）——播放一小时
  /// 就是 3600 次无谓解码。时长发生变化（新曲加载完成）时改走完整推送。
  void _pushElapsed() {
    if (_player.currentSong == null) return;
    if (_player.duration != _lastDuration || _elapsedUnsupported) {
      _pushCurrent();
      return;
    }
    unawaited(
      _controls
          .updateElapsed(
            position: _player.position,
            isPlaying: _player.isPlaying,
          )
          .catchError((Object e, StackTrace s) {
            // 原生未实现（旧二进制 / 平台尚未支持）或通道异常：降级为完整
            // 推送，而不是让每秒的进度刷新变成未处理异常。
            _elapsedUnsupported = true;
            AppLogger.warning(
              'MediaControl',
              'updateElapsed unavailable; falling back to full push',
              e,
              s,
            );
          }),
    );
  }

  void dispose() {
    _eventSub?.cancel();
    _positionTimer?.cancel();
    _player.removeListener(_onPlayerChanged);
    _controls.dispose();
  }
}
