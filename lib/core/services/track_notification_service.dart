import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../utils/logger.dart';
import 'player_service.dart';
import 'settings_service.dart';

/// 切歌通知：每切一首歌弹一条**桌面系统横幅**（macOS 通知中心）。
///
/// 与 [MediaControlService] 是互补关系，互不干扰：
/// - [MediaControlService] 管系统「正在播放」面板与媒体键（`MediaPlayer`）；
/// - 本服务只管横幅通知（`UserNotifications`）。
///
/// 触发来源是 [PlayerService.currentSongNotifier]（已按歌曲 id 去重），
/// 因此手动切歌 / 自动播完进下一首 / 随机 / 循环回环 / 点歌跳转都能覆盖。
///
/// 展示策略：**仅后台弹**。通知的 `presentBanner/presentList/presentAlert`
/// 只影响 App 处于前台时的 `willPresent` 行为——设为 false 后，App 前台
/// （窗口可见，用户本就看得到底栏/播放页）不打扰，后台或关窗驻留时系统照常弹。
///
/// 可在设置页「播放设置 › 切歌时显示系统通知」里关闭（[SettingsService.setShowTrackChangeNotification]）。
class TrackNotificationService {
  TrackNotificationService(this._player, this._settings);

  final PlayerService _player;
  final SettingsService _settings;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 窗口通道（与 `DetailTopBar` 同一条）：点击横幅时把已关闭的窗口唤回。
  static const MethodChannel _windowChannel = MethodChannel(
    'com.jerryc.txvziwm/window',
  );

  /// 固定通知 id：新歌**替换**上一条横幅，而不是在通知中心里越堆越多。
  static const int _notificationId = 1001;

  /// 连续切歌的合并窗口：窗口期内只弹最后确定的当前曲，避免快速连点时刷屏。
  static const Duration _debounce = Duration(milliseconds: 300);

  /// 通知动作分类 id。
  ///
  /// 动作（category）**只能在 initialize 阶段注册**，之后每次 `show` 用
  /// [DarwinNotificationDetails.categoryIdentifier] 引用。
  static const String _categoryId = 'track_actions';

  /// 动作 id：下一首。
  static const String _actionNext = 'next';

  /// 点击横幅 → 打开「正在播放」页。
  ///
  /// 由 App 层注入（core 不能反向依赖 features/），与 `MenuService` 的
  /// 回调注入方式一致。
  VoidCallback? onOpenPlayer;

  Timer? _debounceTimer;
  bool _ready = false;

  /// 权限缓存：一旦拿到授权就不再重复询问。
  ///
  /// **刻意不做"已拒绝"的负缓存**：用户可能事后去系统设置里手动开启，
  /// 下次调用应能重新拿到授权（已决定时 `requestPermissions` 不再弹框，
  /// 只返回当前状态）。
  bool _permissionGranted = false;

  /// 初始化插件并开始监听切歌。
  ///
  /// **不在这里请求授权**：启动就弹权限框体验差。改由 [ensurePermission]
  /// 在两个有上下文的时机申请：设置页打开开关时（明确的用户手势），
  /// 或首次切歌时（该开关默认就是开，老用户可能永远不会去点它，需要兜底）。
  Future<void> initialize() async {
    // 其余桌面平台暂未接入（Windows 需 AUMID/GUID，Linux 需 libnotify/DBus），
    // 先保持 no-op，避免漏传平台 settings 触发运行时 ArgumentError。
    if (!Platform.isMacOS) return;

    try {
      await _plugin.initialize(
        // 含通知动作时不能 const：DarwinNotificationAction 只有 factory 构造。
        settings: InitializationSettings(
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
            // 只加「下一首」：它是**无状态**动作，任何时刻点语义都对。
            // 故意不加「播放/暂停」——那是有状态的，而横幅只在切歌时刷新
            // （暂停不会刷新），会出现"已经暂停了按钮还写着暂停"的错位。
            notificationCategories: [
              DarwinNotificationCategory(
                _categoryId,
                actions: <DarwinNotificationAction>[
                  DarwinNotificationAction.plain(_actionNext, '下一首'),
                ],
              ),
            ],
          ),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );
      // ⚠️ 不能用 initialize() 的返回值判断"是否就绪"：Darwin 实现里它返回的是
      // **权限申请结果**（原生 `requestPermissionsImpl` 的 result）——初始化时我们
      // 把 request*Permission 全设为 false，原生直接 `result(false)` → 恒为 false。
      // 因此只要没抛异常，就说明插件已完成初始化。
      _ready = true;
      AppLogger.info('Notify', 'Notifications initialized');
    } catch (e) {
      AppLogger.warning('Notify', 'Failed to initialize notifications', e);
      return;
    }

    _player.currentSongNotifier.addListener(_onSongChanged);
  }

  void _onSongChanged() {
    final song = _player.currentSongNotifier.value;
    // 停止/清空队列（切到 null）不通知；设置里关掉开关也不通知。
    if (song == null || !_settings.showTrackChangeNotification) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(_showTrack(song)));
  }

  Future<void> _showTrack(Song song) async {
    // 防抖窗口期内用户可能刚把开关关掉，落闸前再确认一次。
    if (!_ready || !_settings.showTrackChangeNotification) return;
    // 未授权时系统会静默丢弃通知，这里提前拦掉；首次切歌会在这一步弹一次
    // 权限框（设置页开开关时已申请过则直接拿到缓存结果）。
    if (!await ensurePermission()) return;

    final attachmentPath = await _copyCoverForAttachment(song);
    final attachments = attachmentPath == null
        ? null
        : <DarwinNotificationAttachment>[
            DarwinNotificationAttachment(attachmentPath),
          ];

    final subtitle = [
      song.artist,
      song.album,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    try {
      await _plugin.show(
        id: _notificationId,
        title: song.title,
        body: subtitle.isEmpty ? null : subtitle,
        payload: song.filePath,
        notificationDetails: NotificationDetails(
          macOS: DarwinNotificationDetails(
            categoryIdentifier: _categoryId,
            // 仅后台弹：前台不打扰，后台/关窗时系统照常展示。
            presentBanner: false,
            presentList: false,
            presentAlert: false, // macOS 10.14~15 的对应选项
            presentSound: false,
            presentBadge: false,
            attachments: attachments,
          ),
        ),
      );
    } catch (e) {
      AppLogger.warning('Notify', 'Failed to show track notification', e);
    }
  }

  /// 把封面**复制**到 App 容器内后返回副本路径（无封面 / 复制失败返回 null）。
  ///
  /// ⚠️ 必须复制，不能把 [Song.albumArtFilePath] 直接交给通知系统：
  /// `UNNotificationAttachment` 会把**不在 App bundle 内**的文件**移动**到系统
  /// 附件库（Apple 文档：只有 bundle 内的文件才是复制；插件 macOS 实现也是把
  /// 路径直接交给 `UNNotificationAttachment`，无任何复制步骤）。我们的封面位于
  /// 沙箱容器 `Documents/covers/` 下、不属于 bundle → 直接传原路径会把 App 自己的
  /// 封面缓存搬走，之后 `CachedAlbumArt` 就再也读不到这张封面了。
  ///
  /// ⚠️ 副本**放在容器内 `Documents/notif_attachments/`，不要用
  /// `getTemporaryDirectory()`**：沙箱下它返回 `/var/folders/...`（`/private/var`
  /// 的符号链接），实测系统读不到该位置 → 通知里不显示缩略图；而容器内
  /// `Documents` 下的路径已被证明可用（修复前直接传原始的封面路径时缩略图能显示）。
  ///
  /// 副本按 song id 固定命名：上次副本若未被系统搬走，先删掉再复制；扩展名沿用
  /// 原图（封面可能是 `.jpg` 或 `.png`，通知系统按扩展名判断类型）。
  Future<String?> _copyCoverForAttachment(Song song) async {
    final coverPath = song.albumArtFilePath;
    if (coverPath == null) return null;
    try {
      final src = File(coverPath);
      if (!await src.exists()) {
        AppLogger.warning('Notify', 'Cover file missing: $coverPath');
        return null;
      }
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDir.path, 'notif_attachments'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final ext = p.extension(coverPath);
      final name = 'cover_${song.id}${ext.isEmpty ? '.jpg' : ext}';
      final dest = File(p.join(dir.path, name));
      if (await dest.exists()) await dest.delete();
      await src.copy(dest.path);
      return dest.path;
    } catch (e) {
      AppLogger.warning('Notify', 'Failed to prepare cover attachment', e);
      return null;
    }
  }

  /// 请求/查询通知授权，返回是否已获授权。
  ///
  /// 两个调用点：① 设置页把开关打开时（明确的用户手势，最自然的时机）；
  /// ② 首次切歌时兜底（开关默认就是开，老用户可能永远不会去点它）。
  /// 已决定过时系统不再弹框，只返回当前状态，因此重复调用是安全的。
  Future<bool> ensurePermission() async {
    if (_permissionGranted) return true;
    if (!Platform.isMacOS) return false;
    try {
      final granted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: false) ??
          false;
      _permissionGranted = granted;
      return granted;
    } catch (e) {
      AppLogger.warning(
        'Notify',
        'Failed to request notification permission',
        e,
      );
      return false;
    }
  }

  /// 打开系统「通知」设置页（用户拒绝后引导其手动开启）。
  Future<void> openNotificationSettings() async {
    try {
      await _plugin.openAppNotificationSettings();
    } catch (e) {
      AppLogger.warning('Notify', 'Failed to open notification settings', e);
    }
  }

  /// 用户与通知交互：动作按钮（下一首）就地执行，点横幅本体才打开播放页。
  void _onResponse(NotificationResponse response) {
    if (response.actionId == _actionNext) {
      AppLogger.info('Notify', 'Notification action: next');
      // 后台静默跳歌：动作未声明 foreground，不会激活窗口；跳完新歌会自然
      // 弹出并替换掉当前这条横幅（同固定 id + 切歌监听）。
      unawaited(_player.next());
      return;
    }
    AppLogger.info('Notify', 'Notification tapped');
    unawaited(_openPlayer());
  }

  Future<void> _openPlayer() async {
    try {
      await _windowChannel.invokeMethod<void>('showMainWindow');
    } catch (_) {
      // 通道不可用（非 macOS / 初始化异常）时忽略：至少把页面打开。
    }
    onOpenPlayer?.call();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _player.currentSongNotifier.removeListener(_onSongChanged);
  }
}
