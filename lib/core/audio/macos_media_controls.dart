import 'dart:async';

import 'package:flutter/services.dart';

import '../utils/logger.dart';
import 'media_control_event.dart';
import 'now_playing_info.dart';
import 'platform_media_controls.dart';

/// macOS implementation backed by `MPRemoteCommandCenter` /
/// `MPNowPlayingInfoCenter` through a native Swift plugin
/// (`macos/Runner/MediaControlsPlugin.swift`).
class MacOsMediaControls implements PlatformMediaControls {
  static const _methodChannel = MethodChannel(
    'com.jerryc.txvziwm/media_controls',
  );
  static const _eventChannel = EventChannel(
    'com.jerryc.txvziwm/media_controls_events',
  );

  final _controller = StreamController<MediaControlEvent>.broadcast();
  StreamSubscription<dynamic>? _eventSub;

  @override
  Stream<MediaControlEvent> get events => _controller.stream;

  @override
  Future<void> setup() async {
    _eventSub ??= _eventChannel.receiveBroadcastStream().listen(
      _onNativeEvent,
      onError: (Object e, StackTrace s) {
        // 事件通道断流/异常会让媒体键静默失效 —— 至少留下日志。
        AppLogger.warning(
          'MediaControl',
          'Media control event stream error',
          e,
          s,
        );
      },
    );
    await _methodChannel.invokeMethod<void>('setup');
  }

  void _onNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    switch (raw['event']) {
      case 'play':
        _controller.add(const PlayEvent());
      case 'pause':
        _controller.add(const PauseEvent());
      case 'toggle':
        _controller.add(const TogglePlayEvent());
      case 'next':
        _controller.add(const NextEvent());
      case 'previous':
        _controller.add(const PreviousEvent());
      case 'seek':
        final ms = raw['positionMs'] as int? ?? 0;
        _controller.add(SeekEvent(Duration(milliseconds: ms)));
    }
  }

  @override
  Future<void> updateNowPlaying(NowPlayingInfo info) async {
    await _methodChannel.invokeMethod<void>('updateNowPlaying', {
      'title': info.title,
      'artist': info.artist,
      'album': info.album,
      'durationMs': info.duration?.inMilliseconds,
      'positionMs': info.position?.inMilliseconds,
      'isPlaying': info.isPlaying,
      'coverFilePath': info.coverFilePath,
    });
  }

  @override
  Future<void> updateElapsed({
    required Duration position,
    required bool isPlaying,
  }) async {
    await _methodChannel.invokeMethod<void>('updateElapsed', {
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
    });
  }

  @override
  Future<void> clearNowPlaying() async {
    await _methodChannel.invokeMethod<void>('clearNowPlaying');
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
    _controller.close();
  }
}
