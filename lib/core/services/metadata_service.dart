import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

import '../../models/scanned_song.dart';
import '../constants/mime_types.dart';
import '../utils/logger.dart';

/// Parses audio metadata from files using [audio_metadata_reader].
///
/// `audio_metadata_reader` 提供**同步**解析 API（`openSync` 读文件）。扫描由
/// UI isolate 触发，因此解析被包进 [Isolate.run] 在后台 isolate 执行，避免
/// 阻塞 UI；并在 isolate 内把结果提取成纯数据 record 回传（`AudioMetadata`
/// 携带 `File` 字段，无法跨 isolate 发送）。
class MetadataService {
  /// Parses metadata from a single audio file.
  ///
  /// If the audio file has no [title] tag, the file name (without extension)
  /// is used as a fallback.
  ///
  /// Returns raw embedded album art bytes via [pictureBytes] / [pictureMimeType].
  /// The caller (e.g. [SongRepository]) is responsible for caching the art
  /// with an album-keyed hash to avoid duplicates.
  ///
  /// Also looks for an external `.lrc` lyrics file alongside the audio file.
  Future<ScannedSong> parse(String filePath) async {
    final file = File(filePath);

    // audio_metadata_reader 是同步解析，丢到后台 isolate 防卡 UI。
    // 闭包只捕获路径字符串（可发送），File 在 isolate 内新建；
    // 返回纯数据 record（AudioMetadata 带 File 字段，不可跨 isolate 发送）。
    final m = await Isolate.run(() {
      final meta = readMetadata(File(filePath), getImage: true);
      final pic = meta.pictures.isNotEmpty ? meta.pictures.first : null;
      return (
        title: meta.title,
        artist: meta.artist,
        albumArtist: meta.albumArtist,
        album: meta.album,
        trackNumber: meta.trackNumber,
        discNumber: meta.discNumber,
        duration: meta.duration,
        year: meta.year,
        genres: List<String>.from(meta.genres),
        lyrics: meta.lyrics,
        bitrate: meta.bitrate,
        sampleRate: meta.sampleRate,
        pictureBytes: pic?.bytes,
        pictureMimeType: pic?.mimetype,
      );
    });

    final fileName = p.basename(filePath);
    final title = (m.title?.trim().isNotEmpty == true)
        ? m.title!.trim()
        : p.basenameWithoutExtension(filePath);

    // ── Extract embedded album art (raw bytes, no caching) ──
    final hasEmbeddedArt = m.pictureBytes != null;
    final pictureMimeType = m.pictureMimeType;

    // ── Embedded lyrics present? (only the flag; text not stored) ──
    final hasEmbeddedLyrics = m.lyrics != null && m.lyrics!.trim().isNotEmpty;

    // ── Look for external .lrc lyrics file ────────────────
    final lyricsPath = _findLrcFile(filePath);
    final stat = await file.stat();

    return ScannedSong(
      filePath: filePath,
      fileName: fileName,
      fileSize: stat.size,
      lastModifiedMs: stat.modified.millisecondsSinceEpoch,
      title: title,
      artist: _nullIfEmpty(m.artist),
      albumArtist: _nullIfEmpty(m.albumArtist),
      album: _nullIfEmpty(m.album),
      trackNumber: m.trackNumber,
      discNumber: m.discNumber,
      durationMs: m.duration?.inMilliseconds,
      year: _yearIfValid(m.year),
      genre: m.genres.isEmpty ? null : m.genres.first,
      bitrate: m.bitrate,
      sampleRate: m.sampleRate,
      mimeType: mimeTypeForPath(filePath) ?? 'audio/unknown',
      pictureBytes: m.pictureBytes,
      pictureMimeType: pictureMimeType,
      hasEmbeddedArt: hasEmbeddedArt,
      hasEmbeddedLyrics: hasEmbeddedLyrics,
      lyricsFilePath: lyricsPath,
    );
  }

  /// Parses metadata for multiple files sequentially.
  ///
  /// [onProgress] is called after each file is parsed.
  Future<(List<ScannedSong>, List<String>)> parseAll(
    List<String> filePaths, {
    void Function(int processed, int total, String currentFile)? onProgress,
  }) async {
    final results = <ScannedSong>[];
    final failures = <String>[];
    final total = filePaths.length;

    for (var i = 0; i < total; i++) {
      final path = filePaths[i];
      try {
        final song = await parse(path);
        results.add(song);
      } catch (e, s) {
        failures.add(path);
        AppLogger.warning('Scan', 'Failed to parse metadata: $path', e, s);
        // If parsing fails, still create a minimal entry with file info
        // and attempt to associate a .lrc file.
        final fileName = p.basename(path);
        final lyricsPath = _findLrcFile(path);
        final fallbackStat = await File(path).stat();
        results.add(
          ScannedSong(
            filePath: path,
            fileName: fileName,
            fileSize: fallbackStat.size,
            lastModifiedMs: fallbackStat.modified.millisecondsSinceEpoch,
            title: p.basenameWithoutExtension(path),
            mimeType: mimeTypeForPath(path) ?? 'audio/unknown',
            lyricsFilePath: lyricsPath,
          ),
        );
      }
      onProgress?.call(i + 1, total, p.basename(path));
    }

    return (results, failures);
  }

  /// 读取单个文件的内嵌歌词（播放时惰性调用）。
  ///
  /// 与 [parse] 不同：只取歌词文本、不读封面（`getImage: false`），更轻量。
  /// 在后台 isolate 执行防卡 UI；返回 trim 后非空的歌词，无内嵌/失败返回 null。
  Future<String?> readEmbeddedLyrics(String filePath) async {
    try {
      return await Isolate.run(() {
        final meta = readMetadata(File(filePath), getImage: false);
        final lyrics = meta.lyrics;
        return (lyrics != null && lyrics.trim().isNotEmpty) ? lyrics : null;
      });
    } catch (e, s) {
      AppLogger.warning(
        'Lyric',
        'Failed to read embedded lyrics: $filePath',
        e,
        s,
      );
      return null;
    }
  }

  /// Looks for a `.lrc` file with the same base name as [audioPath].
  ///
  /// Returns the path if found, or `null` otherwise.
  String? _findLrcFile(String audioPath) {
    final dir = p.dirname(audioPath);
    final baseName = p.basenameWithoutExtension(audioPath);
    final lrcPath = p.join(dir, '$baseName.lrc');
    final lrcFile = File(lrcPath);
    if (lrcFile.existsSync()) {
      return lrcPath;
    }
    // Also check uppercase extension (some files use .LRC)
    final lrcUpperPath = p.join(dir, '$baseName.LRC');
    final lrcUpperFile = File(lrcUpperPath);
    if (lrcUpperFile.existsSync()) {
      return lrcUpperPath;
    }
    return null;
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 过滤无效年份（`AudioMetadata.year` 可能是 `DateTime(0)`，须 year > 0 才存）。
  int? _yearIfValid(DateTime? value) {
    final year = value?.year;
    return (year == null || year <= 0) ? null : year;
  }
}
