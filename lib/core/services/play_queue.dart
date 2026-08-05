import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';

/// Pure data layer for the playback queue.
///
/// Manages [_queue] (song list), [_currentIndex], and JSON persistence.
/// **Does not** touch the audio engine — all mutations are audio-safe and
/// cause no stutter.
///
/// This is a long-lived singleton registered in [ServiceLocator].
class PlayQueue extends ChangeNotifier {
  List<Song> _queue = [];
  int _currentIndex = 0;
  String _repeatModeName = 'off';
  bool _isShuffled = false;

  // ─── Public state ──────────────────────────────────────

  /// The full queue, unmodifiable.
  List<Song> get songs => List.unmodifiable(_queue);

  /// Index of the current (or about-to-play) song.
  int get currentIndex => _currentIndex;

  /// The song at [_currentIndex], or `null` if the queue is empty.
  Song? get currentSong {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex];
  }

  /// Whether the queue has no items.
  bool get isEmpty => _queue.isEmpty;

  /// The number of items in the queue.
  int get length => _queue.length;

  /// Persisted repeat-mode name ('off' | 'one' | 'all').
  String get repeatModeName => _repeatModeName;

  /// Whether shuffle is enabled (persisted).
  bool get isShuffled => _isShuffled;

  // ─── Queue mutations (all audio-safe) ──────────────────

  /// Replace the entire queue with [songs], resetting to [startIndex].
  void replace(List<Song> songs, int startIndex) {
    _queue = List.from(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    _save();
    notifyListeners();
  }

  /// Append [songs] to the tail of the queue.
  void append(List<Song> songs) {
    if (songs.isEmpty) return;
    _queue.addAll(songs);
    _save();
    notifyListeners();
  }

  /// Remove the song at [index] and adjust [_currentIndex] accordingly.
  void removeAt(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
    }
    _save();
    notifyListeners();
  }

  /// Move a song from [oldIndex] to [newIndex] (drag-to-reorder).
  void move(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (oldIndex == newIndex) return;

    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);

    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else {
      if (oldIndex < _currentIndex) _currentIndex--;
      if (newIndex <= _currentIndex) _currentIndex++;
    }
    _save();
    notifyListeners();
  }

  /// Insert [songs] right after the current position.
  void insertAfterCurrent(List<Song> songs) {
    if (songs.isEmpty) return;
    _queue.insertAll(_currentIndex + 1, songs);
    _save();
    notifyListeners();
  }

  /// Empty the queue.
  void clear() {
    _queue = [];
    _currentIndex = 0;
    _save();
    notifyListeners();
  }

  /// Remove every song whose `filePath` is **not** in [validFilePaths].
  ///
  /// Keeps the queue in sync with the library after songs are deleted or
  /// become unavailable (e.g. their folder was removed). The current song
  /// is preserved if it survives; otherwise the index falls back to 0.
  ///
  /// Returns `true` if any song was actually removed, `false` otherwise.
  bool pruneTo(Set<String> validFilePaths) {
    if (_queue.every((s) => validFilePaths.contains(s.filePath))) {
      return false; // nothing to prune
    }

    final currentFilePath = currentSong?.filePath;
    _queue.removeWhere((s) => !validFilePaths.contains(s.filePath));

    if (_queue.isEmpty) {
      _currentIndex = 0;
    } else if (currentFilePath != null) {
      final newIndex = _queue.indexWhere((s) => s.filePath == currentFilePath);
      _currentIndex = newIndex < 0 ? 0 : newIndex;
    } else {
      _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
    }
    _save();
    notifyListeners();
    return true;
  }

  /// Update [_currentIndex] without touching audio.
  void setCurrentIndex(int index) {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _save();
    notifyListeners();
  }

  /// Persist the repeat-mode name.
  void setRepeatModeName(String name) {
    if (_repeatModeName == name) return;
    _repeatModeName = name;
    _save();
    notifyListeners();
  }

  /// Persist the shuffle flag.
  void setIsShuffled(bool value) {
    if (_isShuffled == value) return;
    _isShuffled = value;
    _save();
    notifyListeners();
  }

  // ─── JSON persistence ──────────────────────────────────

  static const _queueFileName = 'play_queue.json';

  /// Load the queue previously saved to disk.
  ///
  /// Call once at startup. Uses [db] to resolve `filePath`s back into full
  /// [Song] objects. Songs whose files are no longer available are skipped.
  Future<void> restoreQueue(FlutterMusicDatabase db) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _queueFileName));
      if (!await file.exists()) return;

      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final filePaths = (data['filePaths'] as List).cast<String>();

      final restored = <Song>[];
      for (final fp in filePaths) {
        final song = await db.getSongByFilePath(fp);
        if (song != null && song.isAvailable == 1) restored.add(song);
      }

      if (restored.isNotEmpty) {
        _queue = restored;
        final savedIndex = data['currentIndex'] as int? ?? 0;
        _currentIndex = savedIndex.clamp(0, restored.length - 1);
      }

      _repeatModeName = data['repeatMode'] as String? ?? 'off';
      _isShuffled = data['isShuffled'] as bool? ?? false;
    } catch (_) {
      _queue = [];
      _currentIndex = 0;
    }
  }

  void _save() {
    _saveToJson();
  }

  Future<void> _saveToJson() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _queueFileName));
      final data = {
        'filePaths': _queue.map((s) => s.filePath).toList(),
        'currentIndex': _currentIndex,
        'repeatMode': _repeatModeName,
        'isShuffled': _isShuffled,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // Silently ignore persistence failures
    }
  }
}
