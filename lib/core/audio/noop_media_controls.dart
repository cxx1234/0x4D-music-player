import 'dart:async';

import 'media_control_event.dart';
import 'now_playing_info.dart';
import 'platform_media_controls.dart';

/// No-op implementation used on platforms that don't support system media
/// controls yet. Prevents crashes when running on unsupported platforms and
/// gives a safe placeholder until the real implementation lands.
class NoOpMediaControls implements PlatformMediaControls {
  static const _empty = Stream<MediaControlEvent>.empty();

  @override
  Stream<MediaControlEvent> get events => _empty;

  @override
  Future<void> setup() async {}

  @override
  Future<void> updateNowPlaying(NowPlayingInfo info) async {}

  @override
  Future<void> clearNowPlaying() async {}

  @override
  void dispose() {}
}
