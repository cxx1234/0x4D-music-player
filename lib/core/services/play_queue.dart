import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../utils/logger.dart';

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
  int _positionMs = 0;
  int _durationMs = 0;

  // ─── Public state ──────────────────────────────────────

  /// The full queue, unmodifiable.
  ///
  /// 缓存视图避免每次访问都拷贝整条队列（QueueView 等高频读取点）。
  /// 用 [UnmodifiableListView] 零拷贝包装，实时反映 _queue 的在位修改；
  /// `_queue` 引用被整体替换（replace/clear/restoreQueue）时须重建视图。
  late List<Song> _songsView = UnmodifiableListView(_queue);

  List<Song> get songs => _songsView;

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

  /// 当前歌曲的播放位置（启动续播用）。
  Duration get position => Duration(milliseconds: _positionMs);

  /// 当前歌曲的总时长（启动续播 / 进度条显示用）。
  Duration get duration => Duration(milliseconds: _durationMs);

  // ─── Queue mutations (all audio-safe) ──────────────────

  /// Replace the entire queue with [songs], resetting to [startIndex].
  void replace(List<Song> songs, int startIndex) {
    _queue = List.from(songs);
    _songsView = UnmodifiableListView(_queue);
    _currentIndex = startIndex.clamp(0, songs.length - 1);
    _positionMs = 0;
    _durationMs = 0;
    _save();
    notifyListeners();
  }

  /// 按 id 替换队列中的歌曲对象（如刷新收藏状态）；不重建音频序列。
  void replaceSong(Song song) {
    final idx = _queue.indexWhere((s) => s.id == song.id);
    if (idx < 0) return;
    _queue[idx] = song;
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
    _songsView = UnmodifiableListView(_queue);
    _currentIndex = 0;
    _positionMs = 0;
    _durationMs = 0;
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

  /// 持久化当前歌曲的播放位置与总时长（不触发 notify；UI 从
  /// positionStream/durationStream 更新，这里仅供启动续播）。
  void setPlaybackState(Duration position, Duration duration) {
    final posMs = position.inMilliseconds;
    final durMs = duration.inMilliseconds;
    if (posMs == _positionMs && durMs == _durationMs) return;
    _positionMs = posMs;
    _durationMs = durMs;
    _save();
  }

  // ─── JSON persistence ──────────────────────────────────

  static const _queueFileName = 'play_queue.json';

  /// 写盘防抖间隔：合并短时间内的连续变更。
  static const _kSaveDebounce = Duration(milliseconds: 500);

  Timer? _saveDebounceTimer;
  bool _savePending = false;

  /// 串行写链：多次写盘按序执行，避免并发 writeAsString 乱序覆盖。
  Future<void> _saveChain = Future.value();

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

      // 批量查一次（WHERE file_path IN (...)），避免逐首单行 SELECT 的 N+1。
      // 返回顺序与 filePaths 一致且仅保留可用歌曲。
      final restored = await db.getSongsByFilePaths(filePaths);

      if (restored.isNotEmpty) {
        _queue = restored;
        _songsView = UnmodifiableListView(_queue);
        final savedIndex = data['currentIndex'] as int? ?? 0;
        _currentIndex = savedIndex.clamp(0, restored.length - 1);
      }

      _repeatModeName = data['repeatMode'] as String? ?? 'off';
      _isShuffled = data['isShuffled'] as bool? ?? false;
      _positionMs = data['positionMs'] as int? ?? 0;
      _durationMs = data['durationMs'] as int? ?? 0;
    } catch (e) {
      AppLogger.warning('Queue', 'Failed to restore queue', e);
      _queue = [];
      _currentIndex = 0;
      _positionMs = 0;
      _durationMs = 0;
    }
  }

  void _save() {
    // 防抖：合并短时间内的连续变更（如 setPlaybackState 每 5s 一次 + 切歌/暂停
    // 叠加），避免每次操作都整份重写 play_queue.json。
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(_kSaveDebounce, () {
      _saveDebounceTimer = null;
      if (_savePending) {
        _savePending = false;
        _enqueueWrite();
      }
    });
    _savePending = true;
  }

  /// 立即落盘（跳过防抖等待），返回写入完成的 Future。
  ///
  /// 供 App 生命周期挂起/退出前调用，避免防抖窗口内的变更丢失。
  Future<void> flushPendingSave() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;
    if (_savePending) {
      _savePending = false;
      _enqueueWrite();
    }
    return _saveChain;
  }

  /// 把一次写盘追加到串行链尾部：写入依次排队，避免并发写乱序覆盖。
  void _enqueueWrite() {
    _saveChain = _saveChain.then((_) => _saveToJson());
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
        'positionMs': _positionMs,
        'durationMs': _durationMs,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      AppLogger.warning('Queue', 'Failed to save queue', e);
    }
  }
}
