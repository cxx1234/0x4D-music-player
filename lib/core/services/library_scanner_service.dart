import 'dart:io';

import '../constants/audio_extensions.dart';
import '../utils/logger.dart';
import 'metadata_service.dart';
import 'song_repository.dart';

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
  final int added;
  final int markedMissing;
  final int skipped;
  final int errors;
  final List<String> errorDetails;

  const ScanResult({
    required this.added,
    required this.markedMissing,
    required this.skipped,
    required this.errors,
    required this.errorDetails,
  });

  int get totalProcessed => added + markedMissing + skipped;

  @override
  String toString() => '添加 $added，标记缺失 $markedMissing，跳过 $skipped，错误 $errors';
}

/// Scans music folders for audio files and syncs them with the database.
///
/// Three-phase workflow:
/// 1. **Collect** — recursively find all audio files in the folders
/// 2. **Diff** — compare with database to find new / missing / existing files
/// 3. **Persist** — parse metadata for new files, mark missing files
class LibraryScannerService {
  final _metadataService = MetadataService();
  final _songRepository = SongRepository();

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
  /// [onProgress] is called throughout the scan to report progress.
  Future<ScanResult> scanFolders(
    List<String> folderPaths, {
    void Function(ScanProgress)? onProgress,
    bool markMissing = true,
    bool updateExisting = false,
  }) async {
    if (folderPaths.isEmpty) {
      return const ScanResult(
        added: 0,
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
    final diskFiles = <String>{};
    for (final folder in folderPaths) {
      final (files, dirErrors) = await _collectAudioFiles(folder);
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
    final changedExistingFiles = updateExisting
        ? existingFiles.where((path) {
            final stamp = existingStamps[path];
            if (stamp == null) return true; // 旧数据无时间戳 → 视为变化
            try {
              final stat = FileStat.statSync(path);
              return stat.modified.millisecondsSinceEpoch !=
                      stamp.lastModifiedMs ||
                  stat.size != stamp.fileSize;
            } catch (_) {
              return true; // 读不到 stat → 交给解析阶段容错
            }
          }).toList()
        : <String>[];
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

    // Count newly added (or updated) files for the result summary.
    final addedCount = filesToParse.length;
    stopwatch.stop();

    // 扫描完成（元数据解析已结束）后统一记录：扫描位置、扫描模式（full/quick）、
    // 收集到的文件总数、增/跳/恢复/缺失/错误数及耗时。无论成功失败都有记录,
    // 便于区分"快速同步"与"全量扫描",并核对本次实际写入量。
    AppLogger.info(
      'Scan',
      'Scan done: ${folderPaths.join(', ')} — '
          'mode ${updateExisting ? 'full' : 'quick'}, '
          'found ${diskFiles.length} audio file(s), '
          'added $addedCount, skipped $skippedCount, '
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
