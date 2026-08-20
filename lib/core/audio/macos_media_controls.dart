import 'dart:async';

import 'package:flutter/services.dart';

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
      onError: (_) {},
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
