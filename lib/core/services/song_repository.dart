import 'package:drift/drift.dart';

import '../../models/scanned_song.dart';
import '../database/database.dart';
import '../database/song_sort_order.dart';
import '../utils/sort_key.dart';
import 'album_art_cache_service.dart';
import 'service_locator.dart';

/// Repository for song data access.
///
/// Wraps [FlutterMusicDatabase] and provides higher-level operations
/// like batch upsert, file-state sync, and folder-scoped queries.
class SongRepository {
  final FlutterMusicDatabase? _database;
  FlutterMusicDatabase get _db => _database ?? ServiceLocator.database;
  final _artCache = AlbumArtCacheService();

  /// [database] is optional and used for testing; defaults to the app-wide
  /// [ServiceLocator.database].
  // ignore: prefer_initializing_formals (公开参数名 database，字段私有 _database)
  SongRepository({FlutterMusicDatabase? database}) : _database = database;

  // ─── Song queries ──────────────────────────────────────

  Future<List<Song>> getAllSongs() => _db.getAllSongs();

  Future<List<Song>> getAvailableSongs({
    SongSortOrder order = SongSortOrder.title,
  }) => _db.getAvailableSongs(order: order);

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

  // ─── Playlist queries ──────────────────────────────────

  Future<List<Playlist>> getAllPlaylists() => _db.getAllPlaylists();

  Stream<List<Playlist>> watchAllPlaylists() => _db.watchAllPlaylists();

  Future<Playlist?> getPlaylistById(int id) => _db.getPlaylistById(id);

  Future<int> insertPlaylist(PlaylistsCompanion entry) =>
      _db.insertPlaylist(entry);

  Future<bool> updatePlaylist(PlaylistsCompanion entry, int id) =>
      _db.updatePlaylist(entry, id);

  Future<void> deletePlaylist(int id) => _db.deletePlaylist(id);

  Future<List<Song>> getSongsInPlaylist(int playlistId, {int? limit}) =>
      _db.getSongsInPlaylist(playlistId, limit: limit);

  Future<void> addSongToPlaylist(int playlistId, int songId) =>
      _db.addSongToPlaylist(playlistId, songId);

  Future<int> addSongsToPlaylist(int playlistId, List<int> songIds) =>
      _db.addSongsToPlaylist(playlistId, songIds);

  Future<void> removeSongFromPlaylist(int playlistId, int songId) =>
      _db.removeSongFromPlaylist(playlistId, songId);

  Future<void> moveSongInPlaylist(int playlistId, int oldIndex, int newIndex) =>
      _db.moveSongInPlaylist(playlistId, oldIndex, newIndex);

  Future<List<Song>> getFavoriteSongs() => _db.getFavoriteSongs();

  Future<int> getFavoriteCount() => _db.getFavoriteCount();

  Future<int> toggleFavorite(int id) => _db.toggleFavorite(id);

  Future<Map<int, int>> getPlaylistSongCounts() => _db.getPlaylistSongCounts();

  // ─── Sort key backfill ────────────────────────────────

  /// 为 sort_key 为空的歌曲/专辑/歌手回填拼音/日文排序键。
  Future<void> backfillSortKeys() async {
    final songs = await _db.getSongsWithNullSortKey();
    for (final song in songs) {
      final key = buildSortKey(song.title);
      if (key.isNotEmpty) {
        await _db.updateSongSortKey(song.id, key);
      }
    }

    final albums = await _db.getAlbumsWithNullSortKey();
    for (final album in albums) {
      final key = buildSortKey(album.name);
      if (key.isNotEmpty) {
        await _db.updateAlbumSortKey(album.id, key);
      }
    }

    final artists = await _db.getArtistsWithNullSortKey();
    for (final artist in artists) {
      final key = buildSortKey(artist.name);
      if (key.isNotEmpty) {
        await _db.updateArtistSortKey(artist.id, key);
      }
    }
  }

  /// 若已有专辑的 albumArtist 为空且当前歌曲提供了专辑艺术家，则补写。
  Future<void> _fillAlbumArtistIfEmpty(Album album, ScannedSong song) async {
    final artist = song.albumArtist ?? song.artist;
    if (artist == null || artist.isEmpty) return;
    final current = album.albumArtist;
    if (current == null || current.isEmpty) {
      await _db.updateAlbum(
        AlbumsCompanion(albumArtist: Value(artist)),
        album.id,
      );
    }
  }

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

    return _db.insertArtist(
      ArtistsCompanion(
        name: Value(name),
        nameSortKey: Value(buildSortKey(name)),
      ),
    );
  }

  // ─── Album helpers ─────────────────────────────────────

  /// Builds a stable album key used for art cache deduplication.
  ///
  /// Uses the album artist (falling back to the song artist) so a compilation
  /// album shared by many artists keeps a single cover.
  String _buildAlbumKey(String albumName, String? albumArtist) {
    return '$albumName::${albumArtist ?? 'Unknown'}';
  }

  /// Finds an existing album for [albumName] / [artistId], or creates a new
  /// one, merging same-named albums across different song artists.
  ///
  /// Resolution order:
  /// 1. Exact match by `(albumName, artistId)` — the fast path for ordinary
  ///    albums and same-name albums by the same artist.
  /// 2. Reuse any existing album with the same name — merges compilation /
  ///    multi-artist albums into a single record. Skipped only when the song
  ///    carries an explicit `albumArtist` tag that differs from the existing
  ///    album's (treated as two distinct albums).
  /// 3. Create a new album (with embedded-art caching).
  ///
  /// If the reused album has no art yet and the current song provides embedded
  /// art, the art is cached using the album key (not the file path), ensuring
  /// one cover per album. Returns `(albumId, albumArtFilePath)`.
  Future<(int, String?)> _getOrCreateAlbum(
    String albumName,
    int? artistId,
    ScannedSong song,
  ) async {
    final albumArtist = song.albumArtist ?? song.artist;
    final albumKey = _buildAlbumKey(albumName, albumArtist);

    // 1) Exact match by name + song artist.
    if (artistId != null) {
      final existing = await _db.getAlbumByNameAndArtist(albumName, artistId);
      if (existing != null) {
        await _fillAlbumArtistIfEmpty(existing, song);
        final artPath = await _ensureAlbumArt(existing, song, albumKey);
        return (existing.id, artPath);
      }
    }

    // 2) Reuse a same-named album (merges multi-artist albums).
    final byName = await _db.getAlbumByName(albumName);
    if (byName != null && !_isDistinctAlbum(byName, song.albumArtist)) {
      await _fillAlbumArtistIfEmpty(byName, song);
      final artPath = await _ensureAlbumArt(byName, song, albumKey);
      return (byName.id, artPath);
    }

    // 3) Create a new album, caching embedded art.
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
        albumArtist: Value(albumArtist),
        nameSortKey: Value(buildSortKey(albumName)),
        albumArtFilePath: Value(albumArtPath),
      ),
    );

    return (albumId, albumArtPath);
  }

  /// Whether a same-named album should be treated as a distinct album
  /// (i.e. NOT merged) — true only when the song carries an explicit
  /// `albumArtist` tag that differs from the existing album's. Without a tag
  /// the albums are merged by name.
  bool _isDistinctAlbum(Album album, String? songAlbumArtist) {
    final tag = songAlbumArtist?.trim();
    if (tag == null || tag.isEmpty) return false;
    final existing = album.albumArtist?.trim();
    if (existing == null || existing.isEmpty) return false;
    return existing != tag;
  }

  /// Returns the album's art path, filling it from the current song's embedded
  /// art (and writing the cached path back to the album) when missing.
  Future<String?> _ensureAlbumArt(
    Album album,
    ScannedSong song,
    String albumKey,
  ) async {
    if (album.albumArtFilePath != null) return album.albumArtFilePath;
    if (!song.hasEmbeddedArt ||
        song.pictureBytes == null ||
        song.pictureMimeType == null) {
      return null;
    }
    try {
      final String path;
      if (await _artCache.hasAlbumArt(albumKey)) {
        path = await _artCache.getAlbumArtPath(albumKey);
      } else {
        path = await _artCache.saveAlbumArt(
          albumKey,
          song.pictureBytes!,
          song.pictureMimeType!,
        );
      }
      await _db.updateAlbum(
        AlbumsCompanion(albumArtFilePath: Value(path)),
        album.id,
      );
      return path;
    } catch (_) {
      // Best-effort: if caching fails, leave art null.
      return null;
    }
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
      titleSortKey: Value(buildSortKey(scanned.title)),
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
