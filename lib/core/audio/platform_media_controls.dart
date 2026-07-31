import 'dart:async';
import 'dart:io';

import 'macos_media_controls.dart';
import 'media_control_event.dart';
import 'noop_media_controls.dart';
import 'now_playing_info.dart';

/// Platform-agnostic facade over the OS's system media controls.
///
/// Concrete implementations talk to each platform's native layer:
/// - **macOS**: `MPRemoteCommandCenter` + `MPNowPlayingInfoCenter`
///   (see [MacOsMediaControls] and `macos/Runner/MediaControlsPlugin.swift`).
/// - **Windows / Linux**: not implemented yet — falls back to
///   [NoOpMediaControls].
///
/// Create an instance for the current platform via [PlatformMediaControls.create].
abstract class PlatformMediaControls {
  /// Stream of user-initiated control events (play / pause / next / …).
  Stream<MediaControlEvent> get events;

  /// Register the app with the system (enable media-command targets).
  Future<void> setup();

  /// Push [info] to the system's Now Playing UI.
  Future<void> updateNowPlaying(NowPlayingInfo info);

  /// Clear the Now Playing info (e.g. queue emptied, playback stopped).
  Future<void> clearNowPlaying();

  /// Release resources / unregister from the system.
  void dispose();

  /// Returns the implementation for the current platform.
  static PlatformMediaControls create() {
    if (Platform.isMacOS) {
      return MacOsMediaControls();
    }
    // TODO(media-controls): Windows (SystemMediaTransportControls) and
    // Linux (MPRIS over D-Bus) implementations — to be added later.
    return NoOpMediaControls();
  }
}
