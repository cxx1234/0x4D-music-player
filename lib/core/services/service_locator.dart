import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../audio/audio_engine_factory.dart';
import '../audio/platform_media_controls.dart';
import '../database/database.dart';
import '../utils/logger.dart';
import 'folder_watcher_service.dart';
import 'hud_service.dart';
import 'lyrics_view_model.dart';
import 'media_control_service.dart';
import 'menu_service.dart';
import 'play_queue.dart';
import 'playback_feedback_service.dart';
import 'player_service.dart';
import 'sandbox_service.dart';
import 'settings_service.dart';
import 'sleep_timer_service.dart';
import 'song_repository.dart';
import 'system_accent_service.dart';
import 'track_notification_service.dart';

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
  static SleepTimerService? _sleepTimer;
  static SandboxService? _sandbox;
  static MediaControlService? _mediaControls;
  static MenuService? _menuService;
  static SystemAccentService? _systemAccent;
  static PlaybackFeedbackService? _feedback;
  static TrackNotificationService? _trackNotifications;

  /// HUD（底部浮动提示）状态源。
  ///
  /// **不随 [initialize] 创建**：它不依赖任何其他服务，而根 Overlay 在初始化
  /// 完成前就已经在构建了（HudOverlay 需要读它），早创建省掉一轮就绪判断。
  static final HudService hud = HudService();

  /// 歌词视图模型（常驻，2026-09-03 起）：与 [PlayerService] 同生命周期。
  ///
  /// 不在播放页内创建——播放页是 push/pop 路由，若 VM 绑在页面上会随关闭销毁、
  /// 重开时重新读盘/解析歌词。提升为全局服务后播放页只消费其 controller。
  static LyricsViewModel? _lyrics;

  /// 应用版本号（来自 pubspec.yaml 的 `version`，如 `0.2.3`）。
  ///
  /// 启动时经 package_info_plus 读取一次并缓存，作为设置页/关于页版本号的
  /// **唯一来源**；读取失败时为 null（UI 端自行兜底）。
  static String? _appVersion;

  static String? get appVersion => _appVersion;

  /// 启动时读取应用版本号；失败仅记日志，不阻塞初始化（测试环境无插件时
  /// PackageInfo.fromPlatform 会抛 MissingPluginException）。
  static Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      AppLogger.info('Startup', 'App version: ${info.version}');
    } catch (e) {
      AppLogger.warning('Startup', 'Failed to read app version', e);
    }
  }

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

  /// 系统强调色桥接服务（仅 macOS；其他平台为 null，跟随系统回退默认色）。
  static SystemAccentService? get systemAccent => _systemAccent;

  /// 外部播放入口（原生菜单 / 媒体键 / 系统「正在播放」面板）的统一出口，
  /// 负责执行动作并发出 HUD 与控件脉冲反馈。
  static PlaybackFeedbackService get feedback {
    if (_feedback == null) {
      throw StateError(
        'PlaybackFeedbackService not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _feedback!;
  }

  /// 切歌通知服务（每切一首弹桌面系统横幅；点击回到「正在播放」）。
  static TrackNotificationService get trackNotifications {
    if (_trackNotifications == null) {
      throw StateError(
        'TrackNotificationService not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _trackNotifications!;
  }

  /// 常驻歌词视图模型（驱动 flutter_lyric controller，含歌词内容/内嵌缓存）。
  static LyricsViewModel get lyrics {
    if (_lyrics == null) {
      throw StateError(
        'Lyrics not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _lyrics!;
  }

  /// 睡眠定时（会话态：到点淡出暂停；不落盘，重启即失效）。
  static SleepTimerService get sleepTimer {
    if (_sleepTimer == null) {
      throw StateError(
        'SleepTimerService not initialized. Call ServiceLocator.initialize() '
        'first.',
      );
    }
    return _sleepTimer!;
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
    // 读取应用版本号（设置页/关于页唯一来源）。置于 initialize() 内并 await，
    // 保证 UI 仅在 isReady 后渲染时一定能读到非空值。
    await _loadAppVersion();
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
      createAudioEngine(),
      playQueue: _playQueue!,
      resumePlaybackPosition: _settings!.settings.resumePlaybackPosition,
      volume: _settings!.settings.volume,
    );
    _sandbox = SandboxService();

    // 睡眠定时（会话态）：与 PlayerService 同生命周期——它把"曲目自然播完"
    // 的钩子挂在播放器上，播放条按钮与原生菜单都只是它的视图。紧跟 player
    // 创建，保证 [isReady] 为真时它必定已就绪（UI 在 build 里就会读它）。
    // 「到点先播完当前曲」的真值在 settings 里 → 传回调现读，避免两处状态同步。
    _sleepTimer = SleepTimerService(
      _player!,
      waitForTrackEnd: () => _settings!.settings.sleepTimerFinishCurrentTrack,
    );

    // 外部操作（菜单/媒体键）的统一出口：菜单与媒体控制都经它转发，
    // 从而共享同一套 HUD 文案与控件脉冲；睡眠定时动作也经它（原生菜单入口）。
    _feedback = PlaybackFeedbackService(_player!, hud, _sleepTimer!);

    // macOS 沙箱：恢复 security-scoped bookmarks（与 UI 生命周期解耦，
    // 保证每次启动都无条件执行，不依赖音乐库页面是否成功渲染）。
    await _restoreSandboxAccess();

    _mediaControls = MediaControlService(
      _player!,
      PlatformMediaControls.create(),
      _feedback!,
    );
    await _mediaControls!.initialize();

    // 切歌通知：与媒体控制互补（前者管系统「正在播放」/媒体键，本服务只管
    // 横幅）。放在沙箱权限恢复之后——通知封面读的是沙箱容器内的 covers 文件。
    _trackNotifications = TrackNotificationService(_player!, _settings!);
    await _trackNotifications!.initialize();

    // 歌词视图模型（常驻，播放页只消费不持有）。创建时机放在沙箱权限恢复
    // （_restoreSandboxAccess）之后——读内嵌/.lrc 歌词需要文件可读。翻译副行
    // 初值取持久化设置，避免启动后用默认 true 与用户上次设置不一致。
    _lyrics = LyricsViewModel(
      _player!,
      initialShowTranslation: _settings!.settings.showTranslation,
    );

    // macOS 菜单桥接：Dart 侧接收原生菜单动作、推送播放状态。
    // 其他平台无原生菜单，不创建（避免通道噪音）。
    if (Platform.isMacOS) {
      _menuService = MenuService.attach(_player!, _feedback!, _sleepTimer!);
    }

    // 系统强调色桥接（仅 macOS；attach 内触发首次读取，失败不抛）。
    // 其他平台保持 null → 「跟随系统」回退默认石墨灰。
    if (Platform.isMacOS) {
      _systemAccent = SystemAccentService.attach();
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
