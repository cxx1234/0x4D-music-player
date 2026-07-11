import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../database/database.dart';

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

  List<Song> _queue = [];
  int _currentIndex = 0;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;
  bool _isShuffled = false;

  // ─── Stream subscriptions ──────────────────────────────

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _sequenceSub;

  PlayerService() {
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
      _currentIndex = _player.currentIndex ?? 0;
      notifyListeners();
    });
  }

  // ─── Public state ──────────────────────────────────────

  /// The full playback queue.
  List<Song> get queue => List.unmodifiable(_queue);

  /// Index of the currently playing (or about-to-play) song.
  int get currentIndex => _currentIndex;

  /// The song currently playing, or `null` if nothing is loaded.
  Song? get currentSong {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex];
  }

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

    _queue = List.from(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);

    final sources = songs
        .map((s) => AudioSource.file(s.filePath) as AudioSource)
        .toList();

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: _currentIndex,
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
    _queue.addAll(songs);
    // Rebuild the audio source with the extended list
    if (_queue.length == songs.length) {
      // Nothing was playing before — start from the first new song
      await playFromList(_queue, startIndex: 0);
    } else {
      final currentFilePath = currentSong?.filePath;
      final currentPosition = _player.position;
      // Rebuild the full sequence preserving the current song & position
      await _rebuildSequence(currentFilePath, currentPosition);
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
    await _player.stop();
    _queue = [];
    _currentIndex = 0;
    notifyListeners();
  }

  /// Skip to the next song.  Wraps around if [repeatMode] is [PlayerRepeatMode.all].
  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      await _player.seekToNext();
    } else if (_repeatMode == PlayerRepeatMode.all) {
      await _player.seek(Duration.zero, index: 0);
    }
    // If repeatMode is `off`, just let playback stop naturally.
  }

  /// Go back to the previous song.
  Future<void> previous() async {
    if (_queue.isEmpty) return;
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

  // ─── Internal helpers ──────────────────────────────────

  Future<void> _rebuildSequence(
    String? currentFilePath,
    Duration position,
  ) async {
    final sources = _queue
        .map((s) => AudioSource.file(s.filePath) as AudioSource)
        .toList();

    final startIndex = currentFilePath != null
        ? _queue.indexWhere((s) => s.filePath == currentFilePath)
        : 0;

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: startIndex < 0 ? 0 : startIndex,
      initialPosition: position,
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
