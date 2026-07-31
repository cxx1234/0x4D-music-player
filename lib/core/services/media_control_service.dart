import 'dart:async';

import '../audio/media_control_event.dart';
import '../audio/now_playing_info.dart';
import '../audio/platform_media_controls.dart';
import '../database/database.dart';
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
        _pushNowPlaying();
      }
    });

    _pushNowPlaying();
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
      _pushNowPlaying();
    }
  }

  void _pushNowPlaying() {
    final song = _player.currentSong;
    if (song == null) {
      _controls.clearNowPlaying();
      return;
    }
    _controls.updateNowPlaying(
      NowPlayingInfo(
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: _player.duration,
        position: _player.position,
        isPlaying: _player.isPlaying,
        coverFilePath: song.albumArtFilePath,
      ),
    );
  }

  void dispose() {
    _eventSub?.cancel();
    _positionTimer?.cancel();
    _player.removeListener(_onPlayerChanged);
    _controls.dispose();
  }
}
