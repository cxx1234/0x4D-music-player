import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../constants/audio_extensions.dart';
import '../utils/logger.dart';
import 'metadata_service.dart';
import 'song_repository.dart';

/// 待处理事件的最新类型：add/modify 归并为 upsert（入库置可用），remove 独立。
enum _PendingKind { upsert, remove }

/// 描述一次去抖批量处理后的文件系统变化（每窗口只发一条汇总事件）。
class FolderWatcherEvent {
  /// 本次新增/更新的文件数。
  final int addedOrUpdated;

  /// 本次移除（标记缺失）的文件数。
  final int removed;

  const FolderWatcherEvent({
    required this.addedOrUpdated,
    required this.removed,
  });

  String get description {
    final parts = <String>[
      if (addedOrUpdated > 0) '添加/更新 $addedOrUpdated',
      if (removed > 0) '移除 $removed',
    ];
    return parts.isEmpty ? '无变化' : parts.join('，');
  }
}

/// Watches configured music folders for file changes in real time.
///
/// Uses the `watcher` package (`dart:io`-based file system watcher).
/// File events are **debounced and batched**: rapid add/modify/remove events
/// accumulate for ~500ms, then flush as one batch — a single [parseAll] + one
/// upsert transaction for adds/mods, one [markMissingFiles] for removes — and
/// a single [FolderWatcherEvent] is emitted. During a scan ([suspend]) events
/// are buffered and processed after [resumeAfterScan], skipping files the scan
/// already parsed (avoid duplicate parse right after a scan).
class FolderWatcherService {
  final MetadataService _metadataService;
  final SongRepository _songRepository;

  final Map<String, StreamSubscription<WatchEvent>> _subscriptions = {};
  final _controller = StreamController<FolderWatcherEvent>.broadcast();

  /// 待处理事件：路径 → (最新类型, 事件到达时间)。
  ///
  /// 记录到达时间是为了在 [resumeAfterScan] 时区分「扫描开始前就已存在的事件」
  /// （可能已被本次扫描覆盖，可安全跳过）与「扫描期间新到的事件」（必须保留，
  /// 否则 force 扫描会把全部文件算作已解析而吞掉这些修改）。
  final Map<String, ({_PendingKind kind, DateTime at})> _pending = {};
  Timer? _flushTimer;
  bool _suspended = false;
  bool _flushing = false;
  bool _disposed = false;

  /// 进入 suspend 的时刻（用于判断事件是否发生在扫描之前）。
  DateTime? _suspendedAt;

  /// 在途 flush 的完成信号：[suspend] 会等它落库结束，避免与扫描事务并发写库。
  Completer<void>? _flushCompleter;

  /// 扫描期间已落库、但被压住的汇总通知（resume 时补发一条）。
  int _deferredUpserts = 0;
  int _deferredRemoves = 0;

  static const _flushDelay = Duration(milliseconds: 500);

  /// [metadataService]/[songRepository] 可选注入，便于测试；默认走全局。
  FolderWatcherService({
    MetadataService? metadataService,
    SongRepository? songRepository,
  }) : _metadataService = metadataService ?? MetadataService(),
       _songRepository = songRepository ?? SongRepository();

  /// Stream of file-system events (one summary per flush).
  Stream<FolderWatcherEvent> get events => _controller.stream;

  /// Whether any folder is currently being watched.
  bool get isWatching => _subscriptions.isNotEmpty;

  /// Returns the list of currently watched folder paths.
  List<String> get watchedFolders => _subscriptions.keys.toList();

  /// 是否有待处理（尚未落库）的文件事件。
  bool get hasPending => _pending.isNotEmpty;

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
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    stopAll();
    _controller.close();
  }

  // ─── Event batching ───────────────────────────────────

  void _handleEvent(WatchEvent event, String folderPath) {
    _record(event.path, event.type);
  }

  /// 记录一条文件系统事件（去抖后批量处理）。供 watcher 回调与测试复用。
  @visibleForTesting
  void recordEvent(String filePath, ChangeType type) {
    _record(filePath, type);
  }

  void _record(String filePath, ChangeType type) {
    if (!isSupportedAudioExtension(filePath)) return;
    _PendingKind kind = _PendingKind.upsert;
    switch (type) {
      case ChangeType.ADD:
      case ChangeType.MODIFY:
        kind = _PendingKind.upsert;
      case ChangeType.REMOVE:
        kind = _PendingKind.remove;
    }
    _pending[filePath] = (kind: kind, at: DateTime.now());
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_disposed || _suspended) return;
    _flushTimer ??= Timer(_flushDelay, () {
      _flushTimer = null;
      unawaited(_flushPending());
    });
  }

  /// 暂停（扫描期间）：事件继续缓冲但不再落库；[resumeAfterScan] 后统一处理。
  ///
  /// 会等待在途的一次 flush 真正落库结束——否则它会与随后的扫描事务并发写
  /// 同一个 drift 库（事务交错 / SQLITE_BUSY）。
  Future<void> suspend() async {
    _suspended = true;
    _suspendedAt = DateTime.now();
    _flushTimer?.cancel();
    _flushTimer = null;
    final inFlight = _flushCompleter;
    if (inFlight != null && !inFlight.isCompleted) {
      await inFlight.future;
    }
  }

  /// 恢复监听（不跳过任何文件）。
  void resume() => _resume(skipUpserts: const {});

  /// 扫描完成后恢复：丢弃/跳过本次扫描已解析过文件的 upsert（与本次扫描集
  /// 求差），避免刚扫完立刻又被 watcher flush 重复解析；remove 不跳过。
  void resumeAfterScan(Set<String> scannedPaths) =>
      _resume(skipUpserts: scannedPaths);

  void _resume({required Set<String> skipUpserts}) {
    if (_disposed) return;
    final suspendedAt = _suspendedAt;
    _suspended = false;
    _suspendedAt = null;
    if (skipUpserts.isNotEmpty) {
      _pending.removeWhere((path, pending) {
        if (pending.kind != _PendingKind.upsert) return false;
        if (!skipUpserts.contains(path)) return false;
        // 只跳过「扫描开始前就已收到」的事件：扫描期间到达的编辑必须保留，
        // 否则 force 扫描（把所有文件都视为已解析）会静默吞掉它们。
        return suspendedAt == null || !pending.at.isAfter(suspendedAt);
      });
    }
    // 补发扫描期间已落库但被压住的汇总通知。
    if (_deferredUpserts > 0 || _deferredRemoves > 0) {
      final upserts = _deferredUpserts;
      final removes = _deferredRemoves;
      _deferredUpserts = 0;
      _deferredRemoves = 0;
      _emitEvent(upserts: upserts, removes: removes);
    }
    if (_pending.isNotEmpty) _scheduleFlush();
  }

  /// 丢弃某文件夹（及子目录）下所有待处理事件（移除该文件夹前调用）。
  void discardPendingUnder(String folderPath) {
    final root = p.normalize(folderPath);
    _pending.removeWhere((path, _) {
      if (path == root) return true;
      return path.startsWith('$root/');
    });
  }

  /// 立即落库所有待处理事件（测试用；内部定时 flush 也走 [_flushPending]）。
  @visibleForTesting
  Future<void> flushNow() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flushPending();
  }

  Future<void> _flushPending() async {
    if (_disposed || _suspended || _flushing) return;
    _flushing = true;
    final completer = _flushCompleter = Completer<void>();
    try {
      if (_pending.isEmpty) return;
      final pending = Map<String, ({_PendingKind kind, DateTime at})>.from(
        _pending,
      );
      _pending.clear();

      final removes = <String>[];
      final upserts = <String>[];
      for (final entry in pending.entries) {
        if (entry.value.kind == _PendingKind.remove) {
          removes.add(entry.key);
        } else {
          upserts.add(entry.key);
        }
      }

      // remove 事件会与 add 乱序到达（覆盖写工具常见）：落库前确认文件确实
      // 不在了，否则会把刚写好的文件瞬时标成不可用。
      final upsertSet = upserts.toSet();
      final realRemoves = [
        for (final path in removes)
          if (!upsertSet.contains(path) && !File(path).existsSync()) path,
      ];

      if (realRemoves.isNotEmpty) {
        await _songRepository.markMissingFiles(realRemoves.toSet(), const {});
      }
      if (upserts.isNotEmpty) {
        final (scanned, failures) = await _metadataService.parseAll(upserts);
        if (failures.isNotEmpty) {
          AppLogger.warning(
            'FolderWatch',
            'Batch parse failed for ${failures.length} file(s)',
          );
        }
        if (scanned.isNotEmpty) {
          await _songRepository.insertOrUpdateFromScan(scanned);
        }
      }

      if (!_disposed) {
        if (_suspended) {
          // 落库完成但正处于扫描期：攒起来，resume 时补发一条汇总通知
          // （否则数据已更新而 UI 不再刷新）。
          _deferredUpserts += upserts.length;
          _deferredRemoves += realRemoves.length;
        } else {
          _emitEvent(upserts: upserts.length, removes: realRemoves.length);
        }
      }
    } catch (e, s) {
      AppLogger.error('FolderWatch', 'Failed to flush folder events', e, s);
    } finally {
      _flushing = false;
      completer.complete();
      if (identical(_flushCompleter, completer)) _flushCompleter = null;
      // 落库期间新到的（或本次未处理完的）事件重新排队。
      if (_pending.isNotEmpty && !_suspended && !_disposed) _scheduleFlush();
    }
  }

  /// 发送一条汇总事件（已 dispose / 流已关闭时静默忽略）。
  void _emitEvent({required int upserts, required int removes}) {
    if (_disposed || _controller.isClosed) return;
    _controller.add(
      FolderWatcherEvent(addedOrUpdated: upserts, removed: removes),
    );
  }
}
