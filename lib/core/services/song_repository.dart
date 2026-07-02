import 'package:drift/drift.dart';
import '../../models/scanned_song.dart';
import '../database/database.dart';
import 'service_locator.dart';

/// Repository for song data access.
///
/// Wraps [FlutterMusicDatabase] and provides higher-level operations
/// like batch upsert, file-state sync, and folder-scoped queries.
class SongRepository {
  FlutterMusicDatabase get _db => ServiceLocator.database;

  // ─── Queries ───────────────────────────────────────────

  Future<List<Song>> getAllSongs() => _db.getAllSongs();

  Future<List<Song>> getAvailableSongs() => _db.getAvailableSongs();

  Stream<List<Song>> watchAllSongs() => _db.watchAllSongs();

  Future<List<Song>> getSongsByFolder(String folderPath) =>
      _db.getSongsByFolder(folderPath);

  Future<Song?> getSongByFilePath(String filePath) =>
      _db.getSongByFilePath(filePath);

  Future<Song?> getSongById(int id) => _db.getSongById(id);

  Future<int> getSongCount() => _db.getSongCount();

  // ─── File paths (for sync) ─────────────────────────────

  /// Returns the set of all available file paths in the database.
  Future<Set<String>> getExistingFilePaths() async {
    final paths = await _db.getAllFilePaths();
    return paths.toSet();
  }

  /// Returns the set of available file paths under [folderPath].
  Future<Set<String>> getFolderFilePaths(String folderPath) async {
    final paths = await _db.getFolderFilePaths(folderPath);
    return paths.toSet();
  }

  // ─── Batch upsert ──────────────────────────────────────

  /// Inserts or updates a list of scanned songs in a single transaction.
  ///
  /// Uses [filePath]'s UNIQUE constraint to decide insert vs update.
  Future<int> insertOrUpdateFromScan(List<ScannedSong> scanned) async {
    if (scanned.isEmpty) return 0;

    var count = 0;
    await _db.transaction(() async {
      for (final song in scanned) {
        await _db.insertSongOnConflictReplace(_toCompanion(song));
        count++;
      }
    });
    return count;
  }

  // ─── File state sync ───────────────────────────────────

  /// Marks files that exist in the database but not on disk as unavailable.
  ///
  /// Returns the list of paths that were marked unavailable.
  Future<List<String>> markMissingFiles(
    Set<String> dbPaths,
    Set<String> diskPaths,
  ) async {
    final missing = dbPaths.difference(diskPaths).toList();
    if (missing.isEmpty) return missing;

    await _db.markAsUnavailable(missing);
    return missing;
  }

  /// Marks files that exist on disk but were previously unavailable as available.
  ///
  /// Returns the number of restored files.
  Future<int> restoreFiles(Set<String> restoredPaths) async {
    var count = 0;
    for (final path in restoredPaths) {
      count += await _db.markAsAvailable(path);
    }
    return count;
  }

  /// Physically deletes all songs under [folderPath] from the database.
  Future<int> removeFolder(String folderPath) async {
    return _db.deleteFolderSongs(folderPath);
  }

  // ─── Helpers ───────────────────────────────────────────

  SongsCompanion _toCompanion(ScannedSong scanned) {
    return SongsCompanion(
      title: Value(scanned.title),
      artist: Value(scanned.artist),
      album: Value(scanned.album),
      trackNumber: Value(scanned.trackNumber),
      discNumber: Value(scanned.discNumber),
      durationMs: Value(scanned.durationMs),
      filePath: Value(scanned.filePath),
      fileName: Value(scanned.fileName),
      fileSize: Value(scanned.fileSize),
      mimeType: Value(scanned.mimeType),
      year: Value(scanned.year),
      genre: Value(scanned.genre),
      bitrate: Value(scanned.bitrate),
      sampleRate: Value(scanned.sampleRate),
      dateAdded: Value(DateTime.now()),
      isAvailable: const Value(1),
    );
  }
}
