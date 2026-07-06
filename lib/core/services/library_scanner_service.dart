import 'dart:io';

import '../constants/audio_extensions.dart';
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
  /// [onProgress] is called throughout the scan to report progress.
  Future<ScanResult> scanFolders(
    List<String> folderPaths, {
    void Function(ScanProgress)? onProgress,
    bool markMissing = true,
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

    // ── Phase 1: Collect files from disk ──────────────────
    onProgress?.call(
      const ScanProgress(
        processed: 0,
        total: 0,
        currentFile: '',
        phase: 'collecting',
      ),
    );

    final diskFiles = <String>{};
    for (final folder in folderPaths) {
      final files = await _collectAudioFiles(folder);
      diskFiles.addAll(files);
    }

    // ── Phase 2: Diff with database ───────────────────────
    final dbFiles = await _songRepository.getExistingFilePaths();

    final newFiles = diskFiles.difference(dbFiles).toList()..sort();
    final restoredFiles = dbFiles
        .where((path) => !diskFiles.contains(path) && File(path).existsSync())
        .toSet();
    final missingFromDb = dbFiles.difference(diskFiles);
    // Remove restored files from the "missing" set
    final trulyMissing = missingFromDb.difference(restoredFiles);

    final skipped = dbFiles.intersection(diskFiles).length;

    onProgress?.call(
      ScanProgress(
        processed: 0,
        total: newFiles.length,
        currentFile: '',
        phase: 'parsing',
      ),
    );

    // ── Phase 3: Parse new files ──────────────────────────
    final errorDetails = <String>[];

    if (newFiles.isNotEmpty) {
      final scanned = await _metadataService.parseAll(
        newFiles,
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

    onProgress?.call(
      ScanProgress(
        processed: newFiles.length,
        total: newFiles.length,
        currentFile: '',
        phase: 'done',
      ),
    );

    return ScanResult(
      added: newFiles.length,
      markedMissing: markedMissing.length,
      skipped: skipped,
      errors: errorDetails.length,
      errorDetails: errorDetails,
    );
  }

  /// Recursively collects all supported audio files under [rootPath].
  Future<List<String>> _collectAudioFiles(String rootPath) async {
    final files = <String>[];
    final dir = Directory(rootPath);

    if (!await dir.exists()) return files;

    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && isSupportedAudioExtension(entity.path)) {
          files.add(entity.path);
        }
      }
    } catch (_) {
      // Skip folders that can't be read
    }

    return files;
  }
}
