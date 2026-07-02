import 'package:flutter/foundation.dart';

import '../../core/database/database.dart';
import '../../core/services/library_scanner_service.dart';
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

  final _scanner = LibraryScannerService();

  // ─── Initialization ────────────────────────────────────

  /// Called when the Library page is first shown.
  ///
  /// Starts folder watchers and runs a quick consistency check.
  Future<void> initialize() async {
    final folders = ServiceLocator.settings.musicFolders;
    if (folders.isNotEmpty) {
      _startWatching(folders);
      // Quick check: scan without re-parsing existing files
      await _quickSync(folders);
    }
    await _loadSongs();
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
      await _scanner.scanFolders(folders);
    } catch (_) {
      // Silently handle quick sync errors
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
    super.dispose();
  }
}
