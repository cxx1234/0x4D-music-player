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

  /// 已知图片扩展名。缓存文件按保存时的 mime 取扩展名(png/webp/gif/bmp/jpg),
  /// 因此读取时需探测真实扩展名,不能恒用 `.jpg`(见 docs/Performance-Optimization.md 5.2)。
  static const List<String> _kKnownExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
  ];

  /// 在 [basePath] (即 `{hash}.`) 下探测已存在的缓存文件,返回真实路径;
  /// 找不到返回 `null`。
  Future<String?> _existingFile(String basePath) async {
    for (final ext in _kKnownExtensions) {
      final f = File('$basePath.$ext');
      if (await f.exists()) return f.path;
    }
    return null;
  }

  /// 删除与 [basePath] 同 hash、但扩展名不同([keepPath] 之外)的残留文件,
  /// 避免 `$hash.jpg` / `$hash.png` 并存导致探测结果不确定。
  Future<void> _deleteStaleSiblings(String basePath, String keepPath) async {
    for (final ext in _kKnownExtensions) {
      final candidate = '$basePath.$ext';
      if (candidate == keepPath) continue;
      try {
        final f = File(candidate);
        if (await f.exists()) await f.delete();
      } catch (e) {
        AppLogger.warning('Cache', 'Failed to delete stale art sibling', e);
      }
    }
  }

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

  /// Returns the cache file path for the given [sourceFilePath].
  ///
  /// 若文件已存在,返回按 mime 保存的真实扩展名路径;否则回退到 `$hash.jpg`。
  Future<String> getArtPath(String sourceFilePath) async {
    final hash = _hashPath(sourceFilePath);
    final dir = await cacheDir;
    final base = p.join(dir.path, hash);
    return await _existingFile(base) ?? '$base.jpg';
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
    final base = p.join(dir.path, hash);
    final filePath = '$base.$ext';
    await File(filePath).writeAsBytes(bytes);
    await _deleteStaleSiblings(base, filePath);
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

  /// Returns the cache file path for the given [albumKey].
  ///
  /// [albumKey] should uniquely identify an album (e.g. `"albumName::artistName"`).
  /// 若文件已存在,返回按 mime 保存的真实扩展名路径;否则回退到 `$hash.jpg`。
  Future<String> getAlbumArtPath(String albumKey) async {
    final hash = _hashPath(albumKey);
    final dir = await cacheDir;
    final base = p.join(dir.path, hash);
    return await _existingFile(base) ?? '$base.jpg';
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
    final base = p.join(dir.path, hash);
    final filePath = '$base.$ext';
    await File(filePath).writeAsBytes(bytes);
    await _deleteStaleSiblings(base, filePath);
    return filePath;
  }

  /// Checks whether art for [albumKey] already exists on disk.
  Future<bool> hasAlbumArt(String albumKey) async {
    final path = await getAlbumArtPath(albumKey);
    return File(path).exists();
  }

  /// 删除 `covers/` 目录中未被 [keepFileNames] 引用的封面文件。
  ///
  /// [keepFileNames] 为仍被引用的文件名集合(如 `a1b2c3d4.jpg`)。
  /// 返回删除的文件数。
  Future<int> deleteOrphans(Set<String> keepFileNames) async {
    final dir = await cacheDir;
    if (!await dir.exists()) return 0;
    var deleted = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (keepFileNames.contains(p.basename(entity.path))) continue;
      try {
        await entity.delete();
        deleted++;
      } catch (e) {
        AppLogger.warning('Cache', 'Failed to delete orphan art', e);
      }
    }
    return deleted;
  }

  /// 统计 `covers/` 目录中所有封面缓存文件的字节总数（目录不存在返回 0）。
  ///
  /// 供设置页「缓存」行显示占用大小。统计失败不抛（记 warning 后返回 0）。
  Future<int> cacheSizeBytes() async {
    try {
      final dir = await cacheDir;
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        try {
          total += await entity.length();
        } catch (_) {
          // 单个文件读取失败（如权限）不影响整体统计。
        }
      }
      return total;
    } catch (e) {
      AppLogger.warning('Cache', 'Failed to compute cache size', e);
      return 0;
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
