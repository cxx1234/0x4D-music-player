import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';

/// Manages on-disk caching of embedded album art images.
///
/// Images are stored under `{appDocDir}/covers/{hash}.{ext}`.
///
/// Two hashing strategies are available:
/// - **Per-file** (`saveArt` / `getArtPath`): hash derived from the source
///   audio file path (legacy, kept for backward compatibility).
/// - **Per-album** (`saveAlbumArt` / `getAlbumArtPath`): hash derived from an
///   album key (e.g. `"albumName::artistName"`), ensuring one cover per album
///   regardless of how many songs belong to it.
class AlbumArtCacheService {
  Directory? _cacheDir;

  /// Ensures the cache directory exists and returns it.
  Future<Directory> get cacheDir async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'covers'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  /// Returns the expected cache file path for the given [sourceFilePath].
  ///
  /// The file may not exist yet — call [saveArt] to create it.
  Future<String> getArtPath(String sourceFilePath) async {
    final hash = _hashPath(sourceFilePath);
    final dir = await cacheDir;
    return p.join(dir.path, '$hash.jpg');
  }

  /// Saves [bytes] to the cache and returns the saved file path.
  ///
  /// [sourceFilePath] is the original audio file path — it is used to derive
  /// a stable cache file name.  [mimeType] (e.g. `"image/jpeg"`,
  /// `"image/png"`) determines the file extension.
  Future<String> saveArt(
    String sourceFilePath,
    Uint8List bytes,
    String mimeType,
  ) async {
    final hash = _hashPath(sourceFilePath);
    final ext = _extensionForMime(mimeType);
    final dir = await cacheDir;
    final filePath = p.join(dir.path, '$hash.$ext');
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  /// Deletes the cached art for [sourceFilePath], if it exists.
  Future<void> deleteArt(String sourceFilePath) async {
    try {
      final path = await getArtPath(sourceFilePath);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.warning('Cache', 'Failed to delete cached art', e);
    }
  }

  /// ─── Per-album art cache ─────────────────────────────

  /// Returns the expected cache file path for the given [albumKey].
  ///
  /// [albumKey] should uniquely identify an album (e.g. `"albumName::artistName"`).
  /// The file may not exist yet — call [saveAlbumArt] to create it.
  Future<String> getAlbumArtPath(String albumKey) async {
    final hash = _hashPath(albumKey);
    final dir = await cacheDir;
    return p.join(dir.path, '$hash.jpg');
  }

  /// Saves album art keyed by [albumKey] and returns the saved file path.
  ///
  /// Unlike [saveArt], this guarantees that the same [albumKey] always maps
  /// to the same file on disk, eliminating duplicate covers.
  Future<String> saveAlbumArt(
    String albumKey,
    Uint8List bytes,
    String mimeType,
  ) async {
    final hash = _hashPath(albumKey);
    final ext = _extensionForMime(mimeType);
    final dir = await cacheDir;
    final filePath = p.join(dir.path, '$hash.$ext');
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  /// Checks whether art for [albumKey] already exists on disk.
  Future<bool> hasAlbumArt(String albumKey) async {
    final path = await getAlbumArtPath(albumKey);
    return File(path).exists();
  }

  /// Computes a deterministic hash of [path] to use as a stable file name.
  ///
  /// Uses a simple FNV-1a hash over the UTF-8 bytes, which is deterministic
  /// across runs and does not require external crypto packages.
  String _hashPath(String path) {
    final bytes = utf8.encode(path);
    var hash = 0x811c9dc5; // FNV offset basis
    for (final b in bytes) {
      hash ^= b;
      hash *= 0x01000193; // FNV prime
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Maps a MIME type to a file extension.
  String _extensionForMime(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/bmp':
        return 'bmp';
      default:
        return 'jpg';
    }
  }
}
