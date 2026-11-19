import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/database/database.dart';
import '../../core/database/song_sort_order.dart';
import '../../core/services/library_scanner_service.dart';
import '../../core/services/player_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/utils/logger.dart';
import '../../core/viewmodels/page_view_model.dart';

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
class LibraryViewModel extends PageViewModel {
  LibraryScanState _scanState = LibraryScanState.idle;

  /// 扫描进度独立通知（ValueNotifier）：进度更新只重建进度条区域，
  /// 不触发整页 setState（避免扫描期间反复重建歌曲大列表拖慢主线程）。
  final ValueNotifier<ScanProgress?> scanProgressNotifier = ValueNotifier(null);
  ScanResult? _scanResult;
  List<Song> _songs = [];
  String? _errorMessage;
  SongSortOrder _sortOrder = SongSortOrder.title;

  /// 扫描单飞守卫：startScan/forceScan/rescan/quickSync 共用，防并发双跑事务。
  bool _scanInProgress = false;

  /// 歌曲列表实时查询的订阅（切换排序时重建）。
  StreamSubscription<List<Song>>? _songsSub;

  LibraryScanState get scanState => _scanState;
  ScanProgress? get scanProgress => scanProgressNotifier.value;
  ScanResult? get scanResult => _scanResult;
  List<Song> get songs => _songs;
  String? get errorMessage => _errorMessage;
  SongSortOrder get sortOrder => _sortOrder;

  bool get isIdle => _scanState == LibraryScanState.idle;
  bool get isScanning => _scanState == LibraryScanState.scanning;
  bool get isDone => _scanState == LibraryScanState.done;
  bool get isError => _scanState == LibraryScanState.error;

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

  /// Play songs in [songs] starting at [index].
  ///
  /// 用于搜索结果等过滤列表，保证"下一首"队列语义限定在该列表内。
  Future<void> playSongsFromList(List<Song> songs, int startIndex) {
    return ServiceLocator.player.playFromList(songs, startIndex: startIndex);
  }

  final _scanner = LibraryScannerService();

  /// 播放态（当前曲 / 播放中）变化的可监听源，供**列表局部重建**。
  ///
  /// 不再用 [safeNotify] 通知整页：音乐库列表里只有行的播放高亮依赖播放态，
  /// 整页 setState（扫描状态条、文件夹列表、工具栏全部跟着重建）纯属浪费。
  ///
  /// 延迟创建：本 VM 在页面 State 构造时即实例化，而 `ServiceLocator.player`
  /// 要等初始化完成后才可用。
  Listenable? _playerUiListenable;

  /// 播放态变化的可监听源（切歌 / 播放态翻转才触发）。
  Listenable get playerUiListenable =>
      _playerUiListenable ??= Listenable.merge([
        ServiceLocator.player.currentSongNotifier,
        ServiceLocator.player.playingNotifier,
      ]);

  /// 订阅音乐库实时查询：扫描、文件夹监视、收藏切换等任何 songs 表写入都会
  /// 触发重新发射，列表与播放队列随之更新 —— 不再依赖 watcher 事件手工重载。
  void _startSongWatch() {
    unawaited(_songsSub?.cancel());
    _songsSub = trackStream(
      ServiceLocator.songRepo.watchAvailableSongs(order: _sortOrder),
      (songs) {
        _songs = songs;
        setLoading(false);
        _syncQueueWithSongs(songs);
        safeNotify();
      },
    );
  }

  /// 从播放队列剪掉库里已不存在的文件（新增/删除后保持队列与库一致）。
  void _syncQueueWithSongs(List<Song> songs) {
    final player = ServiceLocator.player;
    // 空队列无需裁剪（pruneQueue 在空队列时会走 release 分支，避免每次发射都
    // 白跑一趟引擎）。
    if (player.queue.isEmpty) return;
    final available = {for (final song in songs) song.filePath};
    unawaited(player.pruneQueue(available));
  }

  // ─── Initialization ────────────────────────────────────

  /// Called when the Library page is first shown.
  ///
  /// Starts folder watchers and runs a quick consistency check.
  /// Resolves macOS security-scoped bookmarks first to restore sandbox
  /// file access across app restarts.
  Future<void> initialize() async {
    _sortOrder = ServiceLocator.settings.songSortOrder;
    // 先订阅：库里的歌曲立刻可用，不必等 quick sync 扫完（它会写库并触发
    // 一次重新发射）。
    _startSongWatch();

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
    safeNotify();
  }

  /// 切换排序方式并持久化到设置（重新订阅新排序的查询）。
  Future<void> setSortOrder(SongSortOrder order) async {
    if (_sortOrder == order) return;
    _sortOrder = order;
    safeNotify();
    await ServiceLocator.settings.setSongSortOrder(order);
    _startSongWatch();
  }

  // ─── Scanning ──────────────────────────────────────────

  /// Starts a full scan of all configured music folders.
  Future<void> startScan() async {
    final folders = ServiceLocator.settings.musicFolders;
    if (folders.isEmpty) {
      // 诊断「点刷新完全没反应」：未配置音乐文件夹时静默返回。
      AppLogger.warning('Scan', 'startScan skipped: no music folders');
      return;
    }
    await _runScan(folders);
  }

  /// 强制刷新：忽略 mtime/大小变化检测，把全部已存在歌曲重新解析一遍。
  /// 用于文件没变但元数据/封面缓存可能已过期的情况（如封面路径变更后）。
  Future<void> forceScan() async {
    final folders = ServiceLocator.settings.musicFolders;
    if (folders.isEmpty) return;
    await _runScan(folders, force: true);
  }

  /// 仅 debug：模拟一次慢速扫描，驱动进度/结果 UI 便于调试界面。
  ///
  /// 真实扫描常在几十 ms 内完成，进度条与结果横幅一闪而过看不到。
  /// 已注释掉（2026-08-25）：调试扫描 UI 用完后禁用；需要时取消注释，
  /// 并在 library_page 刷新按钮恢复「长按 → simulateScan」即可。
  /*
  Future<void> simulateScan() async {
    if (!kDebugMode) return;
    _scanState = LibraryScanState.scanning;
    scanProgressNotifier.value = null;
    _scanResult = null;
    _errorMessage = null;
    safeNotify();

    const total = 8;
    for (var i = 0; i <= total; i++) {
      scanProgressNotifier.value = ScanProgress(
        processed: i,
        total: total,
        currentFile: i == 0 ? '' : 'Sample song $i.mp3',
        phase: i < 2 ? 'collecting' : 'parsing',
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    _scanResult = const ScanResult(
      added: 3,
      updated: 2,
      markedMissing: 0,
      skipped: 3,
      errors: 0,
      errorDetails: [],
    );
    _scanState = LibraryScanState.done;
    safeNotify();
  }
  */

  /// Re-scans a specific folder.
  Future<void> rescanFolder(String folderPath) async {
    await _runScan([folderPath]);
  }

  /// Removes a folder: stop watching → delete songs from DB → remove from settings.
  Future<void> removeFolder(String folderPath) async {
    ServiceLocator.folderWatcher.stopWatching(folderPath);
    // 清掉该目录下尚未 flush 的监听事件，避免随后误处理已删目录的事件。
    ServiceLocator.folderWatcher.discardPendingUnder(folderPath);
    await ServiceLocator.songRepo.removeFolder(folderPath);
    await ServiceLocator.settings.removeMusicFolder(folderPath);
    safeNotify();
  }

  // ─── Internal ──────────────────────────────────────────

  Future<void> _runScan(List<String> folders, {bool force = false}) async {
    // 单飞：扫描进行中时忽略新的扫描请求（UI 已隐藏刷新按钮，这是 VM 层兜底）。
    if (_scanInProgress) {
      AppLogger.warning('Scan', 'Scan already in progress; request ignored');
      return;
    }
    _scanInProgress = true;
    // 扫描期间暂停文件夹监听：事件缓冲，扫完 resumeAfterScan 批量处理，并跳过
    // 本次已扫描过的文件（与扫描集求差），避免并发写库与重复解析。
    // suspend 会等在途 flush 落库结束，避免它与本次扫描事务并发写库。
    await ServiceLocator.folderWatcher.suspend();

    _scanState = LibraryScanState.scanning;
    scanProgressNotifier.value = null;
    _scanResult = null;
    _errorMessage = null;
    safeNotify();

    ScanResult? result;
    try {
      result = await _scanner.scanFolders(
        folders,
        updateExisting: true,
        force: force,
        onProgress: (progress) {
          // 进度走独立 notifier，不触发整页 setState（避免扫描期间
          // 反复重建歌曲大列表拖慢主线程 / 拖慢扫描）。
          scanProgressNotifier.value = progress;
        },
      );

      _scanResult = result;
      _scanState = result.errors > 0
          ? LibraryScanState.error
          : LibraryScanState.done;
      _startWatching(folders);
    } catch (e, s) {
      // 记录真实异常（此前静默吞掉 → 「一闪而过、无任何提示」）。
      AppLogger.error('Scan', 'Scan failed', e, s);
      _scanState = LibraryScanState.error;
      _errorMessage = e.toString();
    } finally {
      _scanInProgress = false;
      ServiceLocator.folderWatcher.resumeAfterScan(
        result?.parsedFiles ?? const <String>{},
      );
    }

    safeNotify();
  }

  /// 清除扫描结果横幅（扫描完成后 N 秒自动收起时调用）。
  ///
  /// 页面全部保活后 VM 常驻，结果横幅不再随"切换 tab 重建页面"被清掉，
  /// 需要 UI 主动清除，否则会一直挂在页面上。
  void clearScanResult() {
    if (_scanResult == null) return;
    _scanResult = null;
    _scanState = LibraryScanState.idle;
    safeNotify();
  }

  Future<void> _quickSync(List<String> folders) async {
    if (_scanInProgress) {
      AppLogger.warning('Scan', 'Quick sync skipped: a scan is running');
      return;
    }
    _scanInProgress = true;
    await ServiceLocator.folderWatcher.suspend();
    ScanResult? result;
    try {
      result = await _scanner.scanFolders(folders, markMissing: false);
    } catch (e) {
      AppLogger.warning('Scan', 'Quick sync failed', e);
    } finally {
      _scanInProgress = false;
      ServiceLocator.folderWatcher.resumeAfterScan(
        result?.parsedFiles ?? const <String>{},
      );
    }
  }

  void _startWatching(List<String> folders) {
    ServiceLocator.folderWatcher.startWatchingAll(folders);
  }

  @override
  void dispose() {
    scanProgressNotifier.dispose();
    super.dispose(); // 基类置 _disposed 并取消实时查询订阅
  }
}
