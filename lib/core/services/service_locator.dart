import 'dart:io';

import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import '../audio/platform_media_controls.dart';
import '../database/database.dart';
import '../utils/logger.dart';
import 'folder_watcher_service.dart';
import 'media_control_service.dart';
import 'menu_service.dart';
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

  static AppDatabase? _database;
  static SettingsService? _settings;
  static SongRepository? _songRepo;
  static FolderWatcherService? _folderWatcher;
  static PlayQueue? _playQueue;
  static PlayerService? _player;
  static SandboxService? _sandbox;
  static MediaControlService? _mediaControls;
  static MenuService? _menuService;

  /// 启动时恢复沙箱权限失败的文件夹数量（0 = 全部成功）。
  static int _sandboxRestoreFailures = 0;

  static AppDatabase get database {
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

  /// 菜单桥接服务（仅 macOS，Dart↔原生菜单通道）。
  static MenuService get menu {
    if (_menuService == null) {
      throw StateError(
        'MenuService not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _menuService!;
  }

  /// Whether [initialize] has completed.
  static bool get isReady => _player != null;

  /// 启动时恢复沙箱权限失败的文件夹数量（0 = 全部成功）。
  ///
  /// UI 可据此提示用户重新授权音乐文件夹。
  static int get sandboxRestoreFailures => _sandboxRestoreFailures;

  /// 重新授权成功后清零失败计数。
  static void clearSandboxRestoreFailures() {
    _sandboxRestoreFailures = 0;
  }

  /// 落盘所有待写的持久化（如队列防抖窗口内的变更）。
  ///
  /// 供 App 生命周期挂起/退出前调用，避免防抖窗口内的数据丢失。
  static Future<void> flushPendingWrites() async {
    await _playQueue?.flushPendingSave();
  }

  /// 幂等初始化：整个 isolate 生命周期内只执行一次。
  ///
  /// 即使被重复调用（例如某些情况下 initState 再次触发），也返回同一份
  /// 初始化 Future，不会重建任何服务——保证 PlayerService/AudioPlayer
  /// 单例唯一，避免产生"幽灵播放器"（上一个实例的原生播放器未被销毁、
  /// 仍在后台出声/切歌）。
  static Future<void>? _initialization;

  static Future<void> initialize() => _initialization ??= _doInitialize();

  /// 重置初始化缓存,允许重试初始化(启动失败后用户点击重试)。
  ///
  /// [initialize] 是幂等的(`_initialization ??=`),失败后缓存的 Future
  /// 已处于 failed 状态,必须清掉才能重新执行 [_doInitialize]。
  static void resetInitialization() {
    _initialization = null;
  }

  static Future<void> _doInitialize() async {
    AppLogger.info('Startup', 'ServiceLocator.initialize()');
    // 清理上一个 isolate（热重启）遗留的 just_audio 原生播放器，避免
    // "幽灵播放器"在新播放器首次激活前仍在后台出声/切歌。
    try {
      await JustAudioPlatform.instance.disposeAllPlayers(
        DisposeAllPlayersRequest(),
      );
    } catch (e) {
      AppLogger.warning('Startup', 'disposeAllPlayers failed', e);
    }
    _settings = SettingsService();
    await _settings!.initialize();
    _database = await AppDatabase.create();
    _songRepo = SongRepository();
    // 迁移后为 NULL 的 sort_key 回填拼音/日文排序键（一次性）。
    await _songRepo!.backfillSortKeys();
    _folderWatcher = FolderWatcherService();
    _playQueue = PlayQueue();
    await _playQueue!.restoreQueue(_database!);
    _player = PlayerService(
      playQueue: _playQueue!,
      resumePlaybackPosition: _settings!.settings.resumePlaybackPosition,
      volume: _settings!.settings.volume,
    );
    _sandbox = SandboxService();

    // macOS 沙箱：恢复 security-scoped bookmarks（与 UI 生命周期解耦，
    // 保证每次启动都无条件执行，不依赖音乐库页面是否成功渲染）。
    await _restoreSandboxAccess();

    _mediaControls = MediaControlService(
      _player!,
      PlatformMediaControls.create(),
    );
    await _mediaControls!.initialize();

    // macOS 菜单桥接：Dart 侧接收原生菜单动作、推送播放状态。
    // 其他平台无原生菜单，不创建（避免通道噪音）。
    if (Platform.isMacOS) {
      _menuService = MenuService.attach(_player!);
    }
  }

  /// 恢复 macOS security-scoped bookmarks，让音乐文件夹在重启后仍可读。
  ///
  /// resolve 后做读探测确认真实可读；失效的 bookmark 记录日志并累加
  /// [sandboxRestoreFailures]，供 UI 提示用户重新授权。
  static Future<void> _restoreSandboxAccess() async {
    for (final item in _settings!.musicFolderItems) {
      if (item.bookmark.isEmpty) continue;

      final restoredPath = await _sandbox!.resolveBookmark(item.bookmark);
      if (restoredPath == null) {
        _sandboxRestoreFailures++;
        AppLogger.warning(
          'Sandbox',
          'Failed to resolve bookmark for music folder (may be stale): ${item.path}',
        );
        continue;
      }

      // 读探测：resolve 返回路径不代表权限真正生效，实际验证目录可读。
      try {
        final dir = Directory(restoredPath);
        if (!await dir.exists()) {
          _sandboxRestoreFailures++;
          AppLogger.warning(
            'Sandbox',
            'Music folder does not exist: $restoredPath',
          );
        }
      } catch (e) {
        _sandboxRestoreFailures++;
        AppLogger.warning(
          'Sandbox',
          'Music folder read probe failed: $restoredPath',
          e,
        );
      }
    }
  }
}
