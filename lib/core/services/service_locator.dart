import '../audio/platform_media_controls.dart';
import '../database/database.dart';
import 'folder_watcher_service.dart';
import 'media_control_service.dart';
import 'play_queue.dart';
import 'player_service.dart';
import 'sandbox_service.dart';
import 'settings_service.dart';
import 'song_repository.dart';

/// 简单的服务定位器，用于全局访问各项服务。
///
/// 在 App 启动时调用 [initialize] 完成初始化。
class ServiceLocator {
  ServiceLocator._();

  static FlutterMusicDatabase? _database;
  static SettingsService? _settings;
  static SongRepository? _songRepo;
  static FolderWatcherService? _folderWatcher;
  static PlayQueue? _playQueue;
  static PlayerService? _player;
  static SandboxService? _sandbox;
  static MediaControlService? _mediaControls;

  static FlutterMusicDatabase get database {
    if (_database == null) {
      throw StateError(
        'Database not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _database!;
  }

  static SettingsService get settings {
    if (_settings == null) {
      throw StateError(
        'Settings not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _settings!;
  }

  static SongRepository get songRepo {
    if (_songRepo == null) {
      throw StateError(
        'SongRepository not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _songRepo!;
  }

  static FolderWatcherService get folderWatcher {
    if (_folderWatcher == null) {
      throw StateError(
        'FolderWatcherService not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _folderWatcher!;
  }

  static PlayQueue get playQueue {
    if (_playQueue == null) {
      throw StateError(
        'PlayQueue not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _playQueue!;
  }

  static PlayerService get player {
    if (_player == null) {
      throw StateError(
        'PlayerService not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _player!;
  }

  static SandboxService get sandbox {
    if (_sandbox == null) {
      throw StateError(
        'SandboxService not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _sandbox!;
  }

  static MediaControlService get mediaControls {
    if (_mediaControls == null) {
      throw StateError(
        'MediaControlService not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _mediaControls!;
  }

  /// Whether [initialize] has completed.
  static bool get isReady => _player != null;

  static Future<void> initialize() async {
    _settings = SettingsService();
    await _settings!.initialize();
    _database = await FlutterMusicDatabase.create();
    _songRepo = SongRepository();
    // 迁移后为 NULL 的 sort_key 回填拼音/日文排序键（一次性）。
    await _songRepo!.backfillSortKeys();
    _folderWatcher = FolderWatcherService();
    _playQueue = PlayQueue();
    await _playQueue!.restoreQueue(_database!);
    _player = PlayerService(playQueue: _playQueue!);
    _sandbox = SandboxService();

    _mediaControls = MediaControlService(
      _player!,
      PlatformMediaControls.create(),
    );
    await _mediaControls!.initialize();
  }
}
