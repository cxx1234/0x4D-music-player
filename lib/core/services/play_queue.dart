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

  /// Update [_currentIndex] without touching audio.
  void setCurrentIndex(int index) {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
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
        _currentIndex = 0;
      }
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
      final data = {'filePaths': _queue.map((s) => s.filePath).toList()};
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // Silently ignore persistence failures
    }
  }
}
