import 'package:drift/drift.dart';
import '../../models/scanned_song.dart';
import '../database/database.dart';
import 'album_art_cache_service.dart';
import 'service_locator.dart';

/// Repository for song data access.
///
/// Wraps [FlutterMusicDatabase] and provides higher-level operations
/// like batch upsert, file-state sync, and folder-scoped queries.
class SongRepository {
  FlutterMusicDatabase get _db => ServiceLocator.database;
  final _artCache = AlbumArtCacheService();

  // ─── Song queries ──────────────────────────────────────

  Future<List<Song>> getAllSongs() => _db.getAllSongs();

  Future<List<Song>> getAvailableSongs() => _db.getAvailableSongs();

  Stream<List<Song>> watchAllSongs() => _db.watchAllSongs();

  Future<List<Song>> getSongsByFolder(String folderPath) =>
      _db.getSongsByFolder(folderPath);

  Future<Song?> getSongByFilePath(String filePath) =>
      _db.getSongByFilePath(filePath);

  Future<Song?> getSongById(int id) => _db.getSongById(id);

  Future<int> getSongCount() => _db.getSongCount();

  // ─── Album queries ─────────────────────────────────────

  Future<List<Album>> getAllAlbums() => _db.getAllAlbums();

  Stream<List<Album>> watchAllAlbums() => _db.watchAllAlbums();

  Future<Album?> getAlbumById(int id) => _db.getAlbumById(id);

  Future<List<Song>> getSongsByAlbum(int albumId) =>
      _db.getSongsByAlbum(albumId);

  Stream<List<Song>> watchSongsByAlbum(int albumId) =>
      _db.watchSongsByAlbum(albumId);

  // ─── Artist queries ────────────────────────────────────

  Future<List<Artist>> getAllArtists() => _db.getAllArtists();

  Stream<List<Artist>> watchAllArtists() => _db.watchAllArtists();

  Future<Artist?> getArtistById(int id) => _db.getArtistById(id);

  Future<List<Song>> getSongsByArtist(int artistId) =>
      _db.getSongsByArtist(artistId);

  Stream<List<Song>> watchSongsByArtist(int artistId) =>
      _db.watchSongsByArtist(artistId);

  Future<List<Album>> getAlbumsByArtist(int artistId) =>
      _db.getAlbumsByArtist(artistId);

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

  // ─── Batch upsert with album/artist resolution ─────────

  /// Inserts or updates a list of scanned songs in a single transaction.
  ///
  /// For each song:
  /// 1. Looks up (or creates) the [Artist] record by name.
  /// 2. Looks up (or creates) the [Album] record by name + artist.
  /// 3. Deduplicates album art: the first song with embedded art for an album
  ///    saves it (keyed by album identity); subsequent songs reuse the cached
  ///    path stored on the album record.
  /// 4. Writes the song with [artistId], [albumId], and the album's art path.
  ///
  /// Uses [filePath]'s UNIQUE constraint to decide insert vs update.
  Future<int> insertOrUpdateFromScan(List<ScannedSong> scanned) async {
    if (scanned.isEmpty) return 0;

    var count = 0;
    await _db.transaction(() async {
      for (final song in scanned) {
        // ── Resolve artist ──────────────────────────────
        int? artistId;
        if (song.artist != null && song.artist!.trim().isNotEmpty) {
          artistId = await _getOrCreateArtist(song.artist!.trim());
        }

        // ── Resolve album ───────────────────────────────
        int? albumId;
        String? albumArtPath;
        if (song.album != null && song.album!.trim().isNotEmpty) {
          final result = await _getOrCreateAlbum(
            song.album!.trim(),
            artistId,
            song,
          );
          albumId = result.$1;
          albumArtPath = result.$2;
        }

        await _db.insertSongOnConflictReplace(
          _toCompanion(song, artistId, albumId, albumArtPath),
        );
        count++;
      }
    });
    return count;
  }

  // ─── Artist helpers ────────────────────────────────────

  /// Finds an existing artist by name or creates a new one.
  /// Returns the artist's id.
  Future<int> _getOrCreateArtist(String name) async {
    final existing = await _db.getArtistByName(name);
    if (existing != null) return existing.id;

    return _db.insertArtist(ArtistsCompanion(name: Value(name)));
  }

  // ─── Album helpers ─────────────────────────────────────

  /// Builds a stable album key used for art cache deduplication.
  String _buildAlbumKey(String albumName, String? artistName) {
    return '$albumName::${artistName ?? 'Unknown'}';
  }

  /// Finds an existing album by name + artist, or creates a new one.
  ///
  /// If the album doesn't have art yet and the current song provides embedded
  /// art, the art is cached using the album key (not the file path), ensuring
  /// one cover per album.  The album record is updated with the cached path.
  ///
  /// Returns `(albumId, albumArtFilePath)`.
  Future<(int, String?)> _getOrCreateAlbum(
    String albumName,
    int? artistId,
    ScannedSong song,
  ) async {
    final albumKey = _buildAlbumKey(albumName, song.artist);

    // Try to find an existing album.
    if (artistId != null) {
      final existing = await _db.getAlbumByNameAndArtist(albumName, artistId);
      if (existing != null) {
        return (existing.id, existing.albumArtFilePath);
      }
    }

    // If no artistId, search without artist constraint (fallback).
    if (artistId == null) {
      final allAlbums = await _db.getAllAlbums();
      for (final a in allAlbums) {
        if (a.name == albumName) {
          return (a.id, a.albumArtFilePath);
        }
      }
    }

    // ── Deduplicate album art ──────────────────────────
    String? albumArtPath;
    if (song.hasEmbeddedArt &&
        song.pictureBytes != null &&
        song.pictureMimeType != null) {
      // Check if art for this album key already exists on disk.
      // This handles the case where the album record was deleted but the
      // cached file remains.
      if (!await _artCache.hasAlbumArt(albumKey)) {
        try {
          albumArtPath = await _artCache.saveAlbumArt(
            albumKey,
            song.pictureBytes!,
            song.pictureMimeType!,
          );
        } catch (_) {
          // Best-effort: if caching fails, leave art null.
        }
      } else {
        albumArtPath = await _artCache.getAlbumArtPath(albumKey);
      }
    }

    final albumId = await _db.insertAlbum(
      AlbumsCompanion(
        name: Value(albumName),
        artistId: Value(artistId),
        albumArtist: Value(song.artist),
        albumArtFilePath: Value(albumArtPath),
      ),
    );

    return (albumId, albumArtPath);
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

  SongsCompanion _toCompanion(
    ScannedSong scanned,
    int? artistId,
    int? albumId,
    String? albumArtPath,
  ) {
    return SongsCompanion(
      title: Value(scanned.title),
      artist: Value(scanned.artist),
      album: Value(scanned.album),
      artistId: Value(artistId),
      albumId: Value(albumId),
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
      albumArtFilePath: Value(albumArtPath),
      hasEmbeddedArt: Value(scanned.hasEmbeddedArt ? 1 : 0),
      lyricsFilePath: Value(scanned.lyricsFilePath),
      dateAdded: Value(DateTime.now()),
      isAvailable: const Value(1),
    );
  }
}
