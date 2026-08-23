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
  List<Song> get effectiveQueue => _player.effectiveQueue;
  int get effectiveIndex => _player.effectiveIndex;
  int logicalIndexForEffective(int e) => _player.logicalIndexForEffective(e);

  // ─── Lifecycle ─────────────────────────────────────────

  PlayerViewModel() {
    // 只订阅合并通知器（切歌/播放态/队列变化），不再订阅整个 service——
    // 后者随 positionStream 每 ~200ms 触发，会让整页连带重建。
    _player.uiListenable.addListener(_onPlayerChanged);
  }

  void _onPlayerChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _player.uiListenable.removeListener(_onPlayerChanged);
    super.dispose();
  }

  // ─── State reconciliation ──────────────────────────────

  /// 打开"正在播放"界面时，把状态重新对齐到引擎的真实状态。
  void resync() => _player.resyncFromAudio();

  // ─── Playback control ──────────────────────────────────

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> togglePlay() => _player.togglePlay();
  Future<void> next() => _player.next();
  Future<void> previous() => _player.previous();
  Future<void> seek(Duration position) => _player.seek(position);
  PlayerRepeatMode get baseRepeatMode => _player.baseRepeatMode;
  void cyclePlayMode() => _player.cyclePlayMode();
  void toggleSingleRepeat() => _player.toggleSingleRepeat();

  // ─── Queue management ─────────────────────────────────

  Future<void> removeFromQueue(int index) => _player.removeFromQueue(index);
  Future<void> jumpTo(int index) => _player.jumpTo(index);
  Future<void> playNext(List<Song> songs) => _player.playNext(songs);
  Future<void> moveInQueue(int oldIndex, int newIndex) =>
      _player.moveInQueue(oldIndex, newIndex);
  Future<void> clearQueue() => _player.clearQueue();
}
