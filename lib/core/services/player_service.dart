import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../database/database.dart';
import 'play_queue.dart';

/// Available repeat modes for the player.
enum PlayerRepeatMode {
  /// No repeat — stops after the last song.
  off,

  /// Repeats the current song indefinitely.
  one,

  /// Repeats the entire queue.
  all,
}

/// Core audio playback service.
///
/// Wraps [AudioPlayer] from `just_audio` and exposes playback state
/// via [ChangeNotifier].  This is a long-lived singleton — register it
/// in [ServiceLocator] during app startup.
class PlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final PlayQueue _playQueue;
  ConcatenatingAudioSource? _audioSource;

  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;
  bool _isShuffled = false;

  // ─── Stream subscriptions ──────────────────────────────

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _sequenceSub;

  PlayerService({PlayQueue? playQueue})
    : _playQueue = playQueue ?? PlayQueue() {
    // Forward PlayQueue changes to this service's listeners
    _playQueue.addListener(notifyListeners);

    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          _repeatMode == PlayerRepeatMode.off) {
        _player.seek(Duration.zero);
        _player.pause();
      }
      notifyListeners();
    });
    _positionSub = _player.positionStream.listen((_) => notifyListeners());
    _durationSub = _player.durationStream.listen((_) => notifyListeners());
    _sequenceSub = _player.sequenceStateStream.listen((_) {
      final idx = _player.currentIndex ?? 0;
      if (idx >= 0 && idx < _playQueue.length) {
        _playQueue.setCurrentIndex(idx);
      }
      notifyListeners();
    });
  }

  // ─── Public state ──────────────────────────────────────

  /// The playback queue (delegated to [PlayQueue]).
  List<Song> get queue => _playQueue.songs;

  /// Index of the current song.
  int get currentIndex => _playQueue.currentIndex;

  /// The song currently playing, or `null`.
  Song? get currentSong => _playQueue.currentSong;

  /// Whether audio is currently playing.
  bool get isPlaying => _player.playing;

  /// Current playback position.
  Duration get position => _player.position;

  /// Duration of the current song, or [Duration.zero] if unknown.
  Duration get duration => _player.duration ?? Duration.zero;

  /// Current repeat mode.
  PlayerRepeatMode get repeatMode => _repeatMode;

  /// Whether shuffle is enabled.
  bool get isShuffled => _isShuffled;

  // ─── Queue management ──────────────────────────────────

  /// Replace the queue with [songs] and start playing at [startIndex].
  Future<void> playFromList(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    _playQueue.replace(songs, startIndex);

    final sources = songs
        .map((s) => AudioSource.file(s.filePath) as AudioSource)
        .toList();

    _audioSource = ConcatenatingAudioSource(children: sources);
    await _player.setAudioSource(
      _audioSource!,
      initialIndex: _playQueue.currentIndex,
    );
    await _player.play();
  }

  /// Play a single song (replaces the queue with just this one song).
  Future<void> playFromSong(Song song) async {
    await playFromList([song], startIndex: 0);
  }

  /// Append [songs] to the end of the current queue.
  Future<void> addToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    final wasEmpty = _playQueue.isEmpty;
    _playQueue.append(songs);
    if (wasEmpty) {
      final sources = songs
          .map((s) => AudioSource.file(s.filePath) as AudioSource)
          .toList();
      _audioSource = ConcatenatingAudioSource(children: sources);
      await _player.setAudioSource(_audioSource!, initialIndex: 0);
      await _player.play();
    } else {
      final newSources = songs
          .map((s) => AudioSource.file(s.filePath) as AudioSource)
          .toList();
      try {
        await _audioSource?.addAll(newSources);
      } catch (_) {
        await _rebuildSequence();
      }
    }
  }

  // ─── Playback control ──────────────────────────────────

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> stop() async {
    _audioSource = null;
    await _player.stop();
    _playQueue.clear();
  }

  /// Skip to the next song.  Wraps around if [repeatMode] is [PlayerRepeatMode.all].
  Future<void> next() async {
    if (_playQueue.isEmpty) return;
    if (_playQueue.currentIndex < _playQueue.length - 1) {
      await _player.seekToNext();
    } else if (_repeatMode == PlayerRepeatMode.all) {
      await _player.seek(Duration.zero, index: 0);
    }
    // If repeatMode is `off`, just let playback stop naturally.
  }

  /// Go back to the previous song.
  Future<void> previous() async {
    if (_playQueue.isEmpty) return;
    // If more than 3 seconds in, restart the current song.
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  // ─── Mode switching ────────────────────────────────────

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case PlayerRepeatMode.off:
        _repeatMode = PlayerRepeatMode.all;
        _player.setLoopMode(LoopMode.all);
      case PlayerRepeatMode.all:
        _repeatMode = PlayerRepeatMode.one;
        _player.setLoopMode(LoopMode.one);
      case PlayerRepeatMode.one:
        _repeatMode = PlayerRepeatMode.off;
        _player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _isShuffled = !_isShuffled;
    await _player.setShuffleModeEnabled(_isShuffled);
    if (_isShuffled) {
      await _player.shuffle();
    }
    notifyListeners();
  }

  // ─── Queue management ───────────────────────────────

  /// Remove a song from the queue at [index].
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _playQueue.length) return;
    _playQueue.removeAt(index);
    if (_playQueue.isEmpty) {
      _audioSource = null;
      await _player.stop();
      return;
    }
    try {
      await _audioSource?.removeAt(index);
    } catch (_) {
      await _rebuildSequence();
    }
  }

  /// Jump to the song at [index] and play.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _playQueue.length) return;
    _playQueue.setCurrentIndex(index);
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  /// Insert [songs] right after the currently playing song.
  Future<void> playNext(List<Song> songs) async {
    if (songs.isEmpty) return;
    if (_playQueue.isEmpty) {
      await playFromList(songs, startIndex: 0);
      return;
    }
    _playQueue.insertAfterCurrent(songs);
    final newSources = songs
        .map((s) => AudioSource.file(s.filePath) as AudioSource)
        .toList();
    try {
      await _audioSource?.insertAll(_playQueue.currentIndex + 1, newSources);
    } catch (_) {
      await _rebuildSequence();
    }
  }

  /// Move a song from [oldIndex] to [newIndex] (drag-to-reorder).
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    _playQueue.move(oldIndex, newIndex);
    try {
      await _audioSource?.move(oldIndex, newIndex);
    } catch (_) {
      await _rebuildSequence();
    }
  }

  /// Clear the entire queue and stop playback.
  Future<void> clearQueue() async {
    _playQueue.clear();
    _audioSource = null;
    await _player.stop();
  }

  /// Fallback: rebuild the entire audio sequence from scratch.
  /// Used when a dynamic API call ([addAll]/[removeAt]/[move]/[insertAll])
  /// fails — this ensures just_audio's internal sequence stays in sync with
  /// [PlayQueue] even if the platform channel throws.
  Future<void> _rebuildSequence() async {
    final songs = _playQueue.songs;
    if (songs.isEmpty) return;
    final sources = songs
        .map((s) => AudioSource.file(s.filePath) as AudioSource)
        .toList();
    _audioSource = ConcatenatingAudioSource(children: sources);
    await _player.setAudioSource(
      _audioSource!,
      initialIndex: _playQueue.currentIndex.clamp(0, songs.length - 1),
      initialPosition: _player.position,
    );
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _sequenceSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
