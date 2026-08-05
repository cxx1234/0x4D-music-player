import 'package:flutter/foundation.dart';

import '../../core/database/database.dart';
import '../../core/database/song_sort_order.dart';
import '../../core/services/library_scanner_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/service_locator.dart';

/// Possible states of the library scan.
enum LibraryScanState {
  /// No scan has been performed yet.
  idle,

  /// A scan is currently in progress.
  scanning,

  /// The last scan completed successfully.
  done,

  /// The last scan encountered errors.
  error,
}

/// ViewModel for the Library page.
///
/// Manages scan lifecycle, song list, and folder watching.
class LibraryViewModel extends ChangeNotifier {
  LibraryScanState _scanState = LibraryScanState.idle;
  ScanProgress? _scanProgress;
  ScanResult? _scanResult;
  List<Song> _songs = [];
  String? _errorMessage;
  SongSortOrder _sortOrder = SongSortOrder.title;

  LibraryScanState get scanState => _scanState;
  ScanProgress? get scanProgress => _scanProgress;
  ScanResult? get scanResult => _scanResult;
  List<Song> get songs => _songs;
  String? get errorMessage => _errorMessage;
  SongSortOrder get sortOrder => _sortOrder;

  bool get isIdle => _scanState == LibraryScanState.idle;
  bool get isScanning => _scanState == LibraryScanState.scanning;
  bool get isDone => _scanState == LibraryScanState.done;

  // ─── Player delegation ────────────────────────────────

  Song? get currentSong => ServiceLocator.player.currentSong;
  bool get isPlaying => ServiceLocator.player.isPlaying;
  PlayerRepeatMode get repeatMode => ServiceLocator.player.repeatMode;

  /// Play all songs starting from [index].
  Future<void> playSongFromList(int index) {
    return ServiceLocator.player.playFromList(_songs, startIndex: index);
  }

  /// Play a single [song].
  Future<void> playSong(Song song) {
    return ServiceLocator.player.playFromSong(song);
  }

  final _scanner = LibraryScannerService();

  /// 本 ViewModel 是否已注册到 PlayerService 的监听。
  ///
  /// 用于保证「注册最多一次 / 注销彻底一次」。ChangeNotifier 的 addListener
  /// 不去重、removeListener 一次只移除一个匹配项;若 initialize() 被重复调用
  /// (initState / 轮询兜底 / didUpdateWidget 多个触发源)会残留指向已 dispose
  /// 实例的监听,播放时 positionStream 触发即抛 "used after being disposed"。
  bool _playerListenerAttached = false;

  /// 幂等注册:无论调用多少次,PlayerService 上最多挂一个本 VM 的监听。
  void _attachPlayerListener() {
    if (_playerListenerAttached) return;
    ServiceLocator.player.addListener(notifyListeners);
    _playerListenerAttached = true;
  }

  /// 注销注册:页面生命周期结束时调用,保证移除干净。
  void _detachPlayerListener() {
    if (!_playerListenerAttached) return;
    ServiceLocator.player.removeListener(notifyListeners);
    _playerListenerAttached = false;
  }

  // ─── Initialization ────────────────────────────────────

  /// Called when the Library page is first shown.
  ///
  /// Starts folder watchers and runs a quick consistency check.
  /// Resolves macOS security-scoped bookmarks first to restore sandbox
  /// file access across app restarts.
  Future<void> initialize() async {
    _attachPlayerListener();
    final folders = ServiceLocator.settings.musicFolders;
    if (folders.isNotEmpty) {
      // 沙箱权限恢复已在 ServiceLocator.initialize() 完成（与 UI 解耦，
      // 见 ServiceLocator._restoreSandboxAccess）。
      _startWatching(folders);
      // Quick check: scan without re-parsing existing files.
      // markMissing:false ensures we never falsely delete data even if
      // sandbox permissions happen to be unavailable.
      await _quickSync(folders);
    }
    _sortOrder = ServiceLocator.settings.songSortOrder;
    await _loadSongs();
    notifyListeners();
  }

  /// 重新加载歌曲列表（排序或收藏变化后调用）。
  Future<void> reloadSongs() async {
    await _loadSongs();
    notifyListeners();
  }

  /// 切换排序方式并持久化到设置。
  Future<void> setSortOrder(SongSortOrder order) async {
    if (_sortOrder == order) return;
    _sortOrder = order;
    notifyListeners();
    await ServiceLocator.settings.setSongSortOrder(order);
    await _loadSongs();
    notifyListeners();
  }

  // ─── Scanning ──────────────────────────────────────────

  /// Starts a full scan of all configured music folders.
  Future<void> startScan() async {
    final folders = ServiceLocator.settings.musicFolders;
    if (folders.isEmpty) return;
    await _runScan(folders);
  }

  /// Re-scans a specific folder.
  Future<void> rescanFolder(String folderPath) async {
    await _runScan([folderPath]);
  }

  /// Removes a folder: stop watching → delete songs from DB → remove from settings.
  Future<void> removeFolder(String folderPath) async {
    ServiceLocator.folderWatcher.stopWatching(folderPath);
    await ServiceLocator.songRepo.removeFolder(folderPath);
    await ServiceLocator.settings.removeMusicFolder(folderPath);
    await _syncQueueWithLibrary();
    await _loadSongs();
    notifyListeners();
  }

  // ─── Internal ──────────────────────────────────────────

  Future<void> _runScan(List<String> folders) async {
    _scanState = LibraryScanState.scanning;
    _scanProgress = null;
    _scanResult = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _scanner.scanFolders(
        folders,
        updateExisting: true,
        onProgress: (progress) {
          _scanProgress = progress;
          notifyListeners();
        },
      );

      _scanResult = result;
      _scanState = result.errors > 0
          ? LibraryScanState.error
          : LibraryScanState.done;
      _startWatching(folders);
    } catch (e) {
      _scanState = LibraryScanState.error;
      _errorMessage = e.toString();
    }

    await _syncQueueWithLibrary();
    await _loadSongs();
    notifyListeners();
  }

  Future<void> _quickSync(List<String> folders) async {
    try {
      await _scanner.scanFolders(folders, markMissing: false);
    } catch (_) {
      // Silently handle quick sync errors
    }
    await _syncQueueWithLibrary();
  }

  /// 移除音乐库中已不存在的歌曲，保持播放队列与库一致。
  Future<void> _syncQueueWithLibrary() async {
    final available = await ServiceLocator.database.getAllFilePaths();
    await ServiceLocator.player.pruneQueue(available.toSet());
  }

  Future<void> _loadSongs() async {
    _songs = await ServiceLocator.songRepo.getAvailableSongs(order: _sortOrder);
  }

  void _startWatching(List<String> folders) {
    ServiceLocator.folderWatcher.startWatchingAll(folders);
  }

  @override
  void dispose() {
    // 测试环境可能未初始化 ServiceLocator，需要判空。
    if (ServiceLocator.isReady) {
      _detachPlayerListener();
    }
    super.dispose();
  }
}
