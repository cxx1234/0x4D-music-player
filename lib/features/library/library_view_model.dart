import 'package:flutter/foundation.dart';

import '../../core/database/database.dart';
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

  LibraryScanState get scanState => _scanState;
  ScanProgress? get scanProgress => _scanProgress;
  ScanResult? get scanResult => _scanResult;
  List<Song> get songs => _songs;
  String? get errorMessage => _errorMessage;

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

  // ─── Initialization ────────────────────────────────────

  /// Called when the Library page is first shown.
  ///
  /// Starts folder watchers and runs a quick consistency check.
  /// Resolves macOS security-scoped bookmarks first to restore sandbox
  /// file access across app restarts.
  Future<void> initialize() async {
    ServiceLocator.player.addListener(notifyListeners);
    final folders = ServiceLocator.settings.musicFolders;
    if (folders.isNotEmpty) {
      // Resolve any stored macOS security-scoped bookmarks so the
      // app can read these folders (sandbox permission restoration).
      await _resolveBookmarks();

      _startWatching(folders);
      // Quick check: scan without re-parsing existing files.
      // markMissing:false ensures we never falsely delete data even if
      // sandbox permissions happen to be unavailable.
      await _quickSync(folders);
    }
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

    await _loadSongs();
    notifyListeners();
  }

  Future<void> _quickSync(List<String> folders) async {
    try {
      await _scanner.scanFolders(folders, markMissing: false);
    } catch (_) {
      // Silently handle quick sync errors
    }
  }

  /// Resolves macOS security-scoped bookmarks to restore sandbox access.
  ///
  /// Iterates over all stored [MusicFolder] items and resolves their
  /// bookmark data so the app can read those folders after a restart.
  Future<void> _resolveBookmarks() async {
    final items = ServiceLocator.settings.musicFolderItems;
    for (final item in items) {
      if (item.bookmark.isEmpty) continue;
      try {
        await ServiceLocator.sandbox.resolveBookmark(item.bookmark);
      } catch (_) {
        // Stale or invalid bookmark — will be re-created next time the
        // user picks the folder.  Not fatal.
      }
    }
  }

  Future<void> _loadSongs() async {
    _songs = await ServiceLocator.songRepo.getAvailableSongs();
  }

  void _startWatching(List<String> folders) {
    ServiceLocator.folderWatcher.startWatchingAll(folders);
  }

  @override
  void dispose() {
    ServiceLocator.player.removeListener(notifyListeners);
    super.dispose();
  }
}
