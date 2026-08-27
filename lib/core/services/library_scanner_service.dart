import 'dart:io';
import 'dart:isolate';

import '../constants/audio_extensions.dart';
import '../utils/logger.dart';
import 'metadata_service.dart';
import 'song_repository.dart';

/// 全量扫描的变化检测：对每个已存在文件比较 mtime/大小，返回有变化的文件。
///
/// 顶层函数以便 [Isolate.run] 直接调用（捕获的参数均为可跨 isolate 发送的
/// 纯数据：`List<String>` + record Map）。逻辑与旧的内联 where 完全一致：
/// stamp 缺失（旧数据无时间戳）或 stat 失败 → 视为变化（交给解析阶段容错）。
List<String> detectChangedFiles(
  List<String> existingFiles,
  Map<String, ({int? lastModifiedMs, int? fileSize})> stamps,
) {
  final changed = <String>[];
  for (final path in existingFiles) {
    final stamp = stamps[path];
    if (stamp == null) {
      changed.add(path);
      continue;
    }
    try {
      final stat = FileStat.statSync(path);
      if (stat.modified.millisecondsSinceEpoch != stamp.lastModifiedMs ||
          stat.size != stamp.fileSize) {
        changed.add(path);
      }
    } catch (_) {
      changed.add(path);
    }
  }
  return changed;
}

/// 在后台 isolate 里执行变化检测。
///
/// **必须是顶层函数**：`[Isolate.run]` 的闭包只捕获本函数的两个可发送参数。
/// 若把闭包内联在 `scanFolders` 里，会连带捕获调用点的 UI 回调（onProgress →
/// LibraryViewModel → widget 树 → WidgetsFlutterBinding._firstFrameCompleter），
/// 抛 `Illegal argument in isolate message: object is unsendable`（真实环境已复现；
/// 测试因 onProgress 为 null 而通过，故回归测试须用不可发送对象模拟）。
Future<List<String>> _detectChangedInIsolate(
  List<String> existingFiles,
  Map<String, ({int? lastModifiedMs, int? fileSize})> stamps,
) {
  return Isolate.run(() => detectChangedFiles(existingFiles, stamps));
}

/// Progress information emitted during a scan.
class ScanProgress {
  final int processed;
  final int total;
  final String currentFile;
  final String phase; // 'collecting', 'parsing', 'syncing', 'done'

  const ScanProgress({
    required this.processed,
    required this.total,
    required this.currentFile,
    required this.phase,
  });
}

/// Result of a completed scan.
class ScanResult {
  /// 本次**新发现**并解析入库的文件数。
  final int added;

  /// 本次**重新解析**的已存在文件数（增量=有变化的，强制刷新=全部）。
  final int updated;

  final int markedMissing;
  final int skipped;
  final int errors;
  final List<String> errorDetails;

  const ScanResult({
    required this.added,
    required this.updated,
    required this.markedMissing,
    required this.skipped,
    required this.errors,
    required this.errorDetails,
  });

  int get totalProcessed => added + updated + markedMissing + skipped;

  @override
  String toString() =>
      '添加 $added，更新 $updated，标记缺失 $markedMissing，跳过 $skipped，错误 $errors';
}

/// Scans music folders for audio files and syncs them with the database.
///
/// Three-phase workflow:
/// 1. **Collect** — recursively find all audio files in the folders
/// 2. **Diff** — compare with database to find new / missing / existing files
/// 3. **Persist** — parse metadata for new files, mark missing files
class LibraryScannerService {
  final MetadataService _metadataService;
  final SongRepository _songRepository;

  /// [metadataService]/[songRepository] 可选注入，便于测试；默认走全局。
  LibraryScannerService({
    MetadataService? metadataService,
    SongRepository? songRepository,
  }) : _metadataService = metadataService ?? MetadataService(),
       _songRepository = songRepository ?? SongRepository();

  /// Scans one or more [folderPaths] and syncs results to the database.
  ///
  /// When [markMissing] is `false` (default `true`), files present in the
  /// database but not found on disk will **not** be marked unavailable.
  /// Use this for quick/background scans where missing permissions could
  /// falsely indicate file deletion (e.g. macOS sandbox restart).
  ///
  /// When [updateExisting] is `true` (default `false`), files that already
  /// exist in the database will also be re-parsed and their metadata
  /// (album art, lyrics, etc.) updated. Set this for full/refresh scans.
  ///
  /// When [force] is `true` (implies [updateExisting]), the mtime/size
  /// change detection is bypassed and **all** existing files are re-parsed.
  /// Use this for a manual "force refresh" when metadata may be stale even
  /// though the file timestamps/sizes haven't changed (e.g. after a schema
  /// or cover-cache-path change).
  ///
  /// [onProgress] is called throughout the scan to report progress.
  Future<ScanResult> scanFolders(
    List<String> folderPaths, {
    void Function(ScanProgress)? onProgress,
    bool markMissing = true,
    bool updateExisting = false,
    bool force = false,
  }) async {
    if (folderPaths.isEmpty) {
      return const ScanResult(
        added: 0,
        updated: 0,
        markedMissing: 0,
        skipped: 0,
        errors: 0,
        errorDetails: [],
      );
    }

    // 计时:用于最终日志里的耗时统计。
    final stopwatch = Stopwatch()..start();

    // ── Phase 1: Collect files from disk ──────────────────
    onProgress?.call(
      const ScanProgress(
        processed: 0,
        total: 0,
        currentFile: '',
        phase: 'collecting',
      ),
    );

    final errorDetails = <String>[];
    // 多文件夹并行收集（各自独立，Future.wait 叠加磁盘 I/O 等待）。
    final collected = await Future.wait([
      for (final folder in folderPaths) _collectAudioFiles(folder),
    ]);
    final diskFiles = <String>{};
    for (final (files, dirErrors) in collected) {
      diskFiles.addAll(files);
      errorDetails.addAll(dirErrors);
    }

    // ── Phase 2: Diff with database ───────────────────────
    final dbFiles = await _songRepository.getExistingFilePaths();
    final existingStamps = await _songRepository.getExistingFileStats();

    final newFiles = diskFiles.difference(dbFiles).toList()..sort();
    final existingFiles = dbFiles.intersection(diskFiles).toList()..sort();
    final restoredFiles = dbFiles
        .where((path) => !diskFiles.contains(path) && File(path).existsSync())
        .toSet();
    final missingFromDb = dbFiles.difference(diskFiles);
    // Remove restored files from the "missing" set
    final trulyMissing = missingFromDb.difference(restoredFiles);

    // 变化检测:全量扫描只重解析「mtime 或大小」与上次不同的已存在文件,
    // 未变化的直接跳过(计入 skipped),避免每次全量重写整库。
    // force=true 时(强制刷新)忽略变化检测,全部已存在文件都重解析。
    // 检测里的 FileStat.statSync 是同步磁盘 I/O,搬进后台 isolate 不阻塞 UI。
    List<String> changedExistingFiles;
    if (!updateExisting) {
      changedExistingFiles = <String>[];
    } else if (force) {
      changedExistingFiles = existingFiles;
    } else {
      // 变化检测搬进后台 isolate（顶层辅助函数，闭包只捕获数据参数，见
      // [_detectChangedInIsolate]）。万一 isolate 仍失败则降级为「全部视为
      // 变化」重解析，不让整个扫描失败，并打日志暴露原因。
      try {
        changedExistingFiles = await _detectChangedInIsolate(
          existingFiles,
          existingStamps,
        );
      } catch (e, s) {
        AppLogger.warning(
          'Scan',
          'Change detection isolate failed; re-parse all existing files',
          e,
          s,
        );
        changedExistingFiles = existingFiles;
      }
    }
    final skippedCount = existingFiles.length - changedExistingFiles.length;

    // Determine which files to parse: new files + changed existing ones.
    final filesToParse = <String>[...newFiles, ...changedExistingFiles];

    onProgress?.call(
      ScanProgress(
        processed: 0,
        total: filesToParse.length,
        currentFile: '',
        phase: 'parsing',
      ),
    );

    // ── Phase 3: Parse files ──────────────────────────────
    if (filesToParse.isNotEmpty) {
      final (scanned, failures) = await _metadataService.parseAll(
        filesToParse,
        onProgress: (processed, total, currentFile) {
          onProgress?.call(
            ScanProgress(
              processed: processed,
              total: total,
              currentFile: currentFile,
              phase: 'parsing',
            ),
          );
        },
      );
      errorDetails.addAll(failures);

      await _songRepository.insertOrUpdateFromScan(scanned);
    }

    // ── Phase 3b: Restore previously unavailable files ────
    if (restoredFiles.isNotEmpty) {
      await _songRepository.restoreFiles(restoredFiles);
    }

    // ── Phase 3c: Mark missing files ─────────────────────
    final markedMissing = <String>[];
    if (markMissing && trulyMissing.isNotEmpty) {
      await _songRepository.markMissingFiles(dbFiles, diskFiles);
      markedMissing.addAll(trulyMissing);
    }

    // ── Phase 3d: 清理孤儿数据 ──────────────────────────
    // 清理不再被任何歌曲引用的 album/artist/playlist 行,以及未被引用的
    // 封面缓存文件(例如歌曲改了专辑后旧专辑及其封面成为孤儿)。
    await _songRepository.cleanupOrphans();
    await _songRepository.cleanupOrphanCovers();

    onProgress?.call(
      ScanProgress(
        processed: filesToParse.length,
        total: filesToParse.length,
        currentFile: '',
        phase: 'done',
      ),
    );

    // Count newly added vs re-parsed existing files for the result summary.
    final addedCount = newFiles.length;
    final updatedCount = changedExistingFiles.length;
    stopwatch.stop();

    // 扫描完成（元数据解析已结束）后统一记录：扫描位置、扫描模式（full/quick、
    // 可选 force 强制）、收集到的文件总数、增/更新/跳/恢复/缺失/错误数及耗时。
    // 无论成功失败都有记录,便于区分"快速同步"与"全量扫描",并核对本次实际写入量。
    AppLogger.info(
      'Scan',
      'Scan done: ${folderPaths.join(', ')} — '
          'mode ${updateExisting ? 'full' : 'quick'}${force ? '+force' : ''}, '
          'found ${diskFiles.length} audio file(s), '
          'added $addedCount, updated $updatedCount, skipped $skippedCount, '
          'restored ${restoredFiles.length}, missing ${markedMissing.length}, '
          'errors ${errorDetails.length}, took ${stopwatch.elapsedMilliseconds}ms',
    );

    // 批量失败聚合为一条 error 日志,避免逐文件刷屏(单文件失败已在上层
    // 记录 warning)。
    if (errorDetails.isNotEmpty) {
      AppLogger.error(
        'Scan',
        'Scan finished with ${errorDetails.length} failure(s):\n'
            '  ${errorDetails.join('\n  ')}',
      );
    }

    return ScanResult(
      added: addedCount,
      updated: updatedCount,
      markedMissing: markedMissing.length,
      skipped: skippedCount,
      errors: errorDetails.length,
      errorDetails: errorDetails,
    );
  }

  /// Recursively collects all supported audio files under [rootPath].
  ///
  /// 返回 (文件列表, 目录级错误列表)。目录不存在或不可读时,错误会
  /// 计入统计并在日志中记录,而不是静默跳过。
  Future<(List<String>, List<String>)> _collectAudioFiles(
    String rootPath,
  ) async {
    final files = <String>[];
    final errors = <String>[];
    final dir = Directory(rootPath);

    if (!await dir.exists()) {
      errors.add('Directory does not exist: $rootPath');
      AppLogger.warning('Scan', 'Cannot read directory: $rootPath');
      return (files, errors);
    }

    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && isSupportedAudioExtension(entity.path)) {
          files.add(entity.path);
        }
      }
    } catch (e, s) {
      // 目录不可读:记录日志并计入错误统计(用户可在扫描结果中看到)。
      errors.add('Cannot read directory: $rootPath');
      AppLogger.warning('Scan', 'Cannot read directory: $rootPath', e, s);
    }

    return (files, errors);
  }
}
