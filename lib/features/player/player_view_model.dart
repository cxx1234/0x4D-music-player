import 'package:flutter/foundation.dart';

import '../../core/database/database.dart';
import '../../core/services/player_service.dart';
import '../../core/services/service_locator.dart';

/// ViewModel for [PlayerPage].
///
/// Delegates all playback logic to [PlayerService] and exposes
/// only the state that the UI layer needs.
class PlayerViewModel extends ChangeNotifier {
  PlayerService get _player => ServiceLocator.player;

  // ─── Delegated getters ─────────────────────────────────

  Song? get currentSong => _player.currentSong;
  bool get isPlaying => _player.isPlaying;
  Duration get position => _player.position;
  Duration get duration => _player.duration;
  PlayerRepeatMode get repeatMode => _player.repeatMode;
  bool get isShuffled => _player.isShuffled;
  List<Song> get queue => _player.queue;
  int get currentIndex => _player.currentIndex;

  // ─── Lifecycle ─────────────────────────────────────────

  PlayerViewModel() {
    _player.addListener(_onPlayerChanged);
  }

  void _onPlayerChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    super.dispose();
  }

  // ─── Playback control ──────────────────────────────────

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> togglePlay() => _player.togglePlay();
  Future<void> next() => _player.next();
  Future<void> previous() => _player.previous();
  Future<void> seek(Duration position) => _player.seek(position);
  void cycleRepeatMode() => _player.cycleRepeatMode();
  Future<void> toggleShuffle() => _player.toggleShuffle();
}
