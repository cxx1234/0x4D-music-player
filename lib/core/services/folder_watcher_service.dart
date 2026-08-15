import 'dart:async';

import 'package:watcher/watcher.dart';

import '../constants/audio_extensions.dart';
import '../utils/logger.dart';
import 'metadata_service.dart';
import 'song_repository.dart';

/// Describes a file system event relevant to the music library.
class FolderWatcherEvent {
  final String filePath;
  final String folderPath;
  final String description;

  const FolderWatcherEvent({
    required this.filePath,
    required this.folderPath,
    required this.description,
  });
}

/// Watches configured music folders for file changes in real time.
///
/// Uses the `watcher` package (`dart:io`-based file system watcher).
/// For each folder, a [DirectoryWatcher] monitors add / remove / modify events.
class FolderWatcherService {
  final _metadataService = MetadataService();
  final _songRepository = SongRepository();

  final Map<String, StreamSubscription<WatchEvent>> _subscriptions = {};
  final _controller = StreamController<FolderWatcherEvent>.broadcast();

  /// Stream of file-system events detected by watchers.
  Stream<FolderWatcherEvent> get events => _controller.stream;

  /// Whether any folder is currently being watched.
  bool get isWatching => _subscriptions.isNotEmpty;

  /// Returns the list of currently watched folder paths.
  List<String> get watchedFolders => _subscriptions.keys.toList();

  /// Starts watching a single [folderPath].
  ///
  /// Ignores files that are not supported audio files.
  /// If the folder is already being watched, this is a no-op.
  void startWatching(String folderPath) {
    if (_subscriptions.containsKey(folderPath)) return;

    final watcher = DirectoryWatcher(folderPath);
    final sub = watcher.events.listen((event) {
      _handleEvent(event, folderPath);
    });

    _subscriptions[folderPath] = sub;
  }

  /// Starts watching all folders in [folderPaths].
  void startWatchingAll(Iterable<String> folderPaths) {
    for (final folder in folderPaths) {
      startWatching(folder);
    }
  }

  /// Stops watching a single [folderPath].
  void stopWatching(String folderPath) {
    final sub = _subscriptions.remove(folderPath);
    sub?.cancel();
  }

  /// Stops watching all folders.
  void stopAll() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Disposes the service, stopping all watchers and closing the stream.
  void dispose() {
    stopAll();
    _controller.close();
  }

  // ─── Event handler ────────────────────────────────────

  void _handleEvent(WatchEvent event, String folderPath) {
    if (!isSupportedAudioExtension(event.path)) return;

    switch (event.type) {
      case ChangeType.ADD:
        _onFileAdded(event.path, folderPath);
      case ChangeType.REMOVE:
        _onFileRemoved(event.path, folderPath);
      case ChangeType.MODIFY:
        _onFileModified(event.path, folderPath);
    }
  }

  void _onFileAdded(String filePath, String folderPath) {
    _metadataService
        .parse(filePath)
        .then((scanned) async {
          await _songRepository.insertOrUpdateFromScan([scanned]);
          _controller.add(
            FolderWatcherEvent(
              filePath: filePath,
              folderPath: folderPath,
              description: '新歌曲已添加',
            ),
          );
        })
        .catchError((e, s) {
          AppLogger.warning(
            'FolderWatch',
            'Failed to parse added file: $filePath',
            e,
            s,
          );
        });
  }

  void _onFileRemoved(String filePath, String folderPath) {
    _songRepository
        .getSongByFilePath(filePath)
        .then((song) async {
          if (song != null) {
            await _songRepository.markMissingFiles({filePath}, {});
            _controller.add(
              FolderWatcherEvent(
                filePath: filePath,
                folderPath: folderPath,
                description: '歌曲文件已移除',
              ),
            );
          }
        })
        .catchError((e, s) {
          AppLogger.warning(
            'FolderWatch',
            'Failed to handle removed file: $filePath',
            e,
            s,
          );
        });
  }

  void _onFileModified(String filePath, String folderPath) {
    _metadataService
        .parse(filePath)
        .then((scanned) async {
          await _songRepository.insertOrUpdateFromScan([scanned]);
          _controller.add(
            FolderWatcherEvent(
              filePath: filePath,
              folderPath: folderPath,
              description: '歌曲信息已更新',
            ),
          );
        })
        .catchError((e, s) {
          AppLogger.warning(
            'FolderWatch',
            'Failed to parse modified file: $filePath',
            e,
            s,
          );
        });
  }
}
