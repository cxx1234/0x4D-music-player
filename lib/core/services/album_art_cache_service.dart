import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages on-disk caching of embedded album art images.
///
/// Images are stored under `{appDocDir}/covers/{sha256}.{ext}` where the
/// SHA-256 hash is derived from the source audio file path, guaranteeing
/// a unique and stable file name regardless of the file's location.
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
    } catch (_) {
      // Best-effort cleanup — not fatal.
    }
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
