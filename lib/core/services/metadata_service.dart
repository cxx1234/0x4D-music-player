import 'dart:io';
import 'dart:isolate';
import 'dart:math' show min;

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

import '../../models/scanned_song.dart';
import '../constants/mime_types.dart';
import '../utils/logger.dart';

/// 单个文件解析结果（批量 isolate 的返回值单元）。
///
/// [failed] 为 true 时 [song] 为 null（解析失败，由主 isolate 构造降级条目）。
typedef _ParseOutcome = ({String path, ScannedSong? song, bool failed});

/// Parses audio metadata from files using [audio_metadata_reader].
///
/// `audio_metadata_reader` 提供**同步**解析 API（`openSync` 读文件）。扫描由
/// UI isolate 触发，因此解析被包进 [Isolate.run] 在后台 isolate 执行，避免
/// 阻塞 UI。
///
/// 批量解析（[parseAll]）采用**受限并发 + 批量 isolate**：
/// - 文件按并发数分成若干 chunk，每个 chunk 丢给一个 isolate 顺序解析
///   （减少 isolate 创建/传输开销），chunk 之间并行（`Future.wait`）；
/// - 并发数 = CPU 核数，钳制在 [1, _kMaxConcurrency]；
/// - 返回的 [ScannedSong] 是纯数据（含 Uint8List 封面），可跨 isolate 发送。
class MetadataService {
  /// 并发上限（多个 isolate 同时读大文件 + 封面，内存考虑）。
  static const int _kMaxConcurrency = 8;

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
  ///
  /// 解析失败时**不抛异常**，返回降级条目（文件名兜底标题，供 watch/scan 统一）。
  Future<ScannedSong> parse(String filePath) async {
    try {
      return await Isolate.run(() => _parseSync(filePath));
    } catch (e, s) {
      AppLogger.warning('Scan', 'Failed to parse metadata: $filePath', e, s);
      return _fallbackSong(filePath);
    }
  }

  /// Parses metadata for multiple files with bounded concurrency.
  ///
  /// 文件按并发数分块，每块一个 isolate 顺序解析，块间并行（[Future.wait]）。
  /// [onProgress] 每解析完一个文件回调一次（processed 为累计已完成数）。
  Future<(List<ScannedSong>, List<String>)> parseAll(
    List<String> filePaths, {
    void Function(int processed, int total, String currentFile)? onProgress,
  }) async {
    final results = <ScannedSong>[];
    final failures = <String>[];
    final total = filePaths.length;
    if (total == 0) return (results, failures);

    // 并发数：CPU 核数，钳制在 [1, _kMaxConcurrency]。
    final concurrency = Platform.numberOfProcessors.clamp(1, _kMaxConcurrency);

    // 按并发数把文件分成若干 chunk，每个 chunk 一个 isolate。
    final chunkSize = (total / concurrency).ceil();
    final chunks = <List<String>>[];
    for (var i = 0; i < total; i += chunkSize) {
      chunks.add(filePaths.sublist(i, min(i + chunkSize, total)));
    }

    // 各 chunk 并行解析；单个 chunk 的 isolate 异常不会拖垮整批。
    final chunkResults = await Future.wait(
      chunks.map((chunk) async {
        try {
          return await Isolate.run(() => _parseBatch(chunk));
        } catch (e, s) {
          AppLogger.warning('Scan', 'Batch isolate failed', e, s);
          return chunk
              .map((path) => (path: path, song: null, failed: true))
              .toList();
        }
      }),
    );

    // 汇总：失败路径记入 failures 并构造降级条目，行为与串行版一致。
    var processed = 0;
    for (final batch in chunkResults) {
      for (final outcome in batch) {
        processed++;
        if (outcome.failed) {
          failures.add(outcome.path);
          AppLogger.warning('Scan', 'Failed to parse metadata: ${outcome.path}');
          results.add(_fallbackSong(outcome.path));
        } else {
          results.add(outcome.song!);
        }
        onProgress?.call(processed, total, p.basename(outcome.path));
      }
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

  /// 解析失败时的降级条目：文件名兜底标题 + 关联 .lrc（主 isolate 调用）。
  ScannedSong _fallbackSong(String filePath) {
    final file = File(filePath);
    return ScannedSong(
      filePath: filePath,
      fileName: p.basename(filePath),
      fileSize: file.existsSync() ? file.lengthSync() : 0,
      lastModifiedMs: _fileModifiedMsSync(filePath),
      title: p.basenameWithoutExtension(filePath),
      mimeType: mimeTypeForPath(filePath) ?? 'audio/unknown',
      lyricsFilePath: _findLrcFile(filePath),
    );
  }
}

/// 同步解析单个文件（isolate 内运行；也供 [MetadataService.parse] 使用）。
///
/// 提取成顶层函数以便 [Isolate.run] 直接调用（不捕获实例，规避 send 限制）。
ScannedSong _parseSync(String filePath) {
  final file = File(filePath);
  final meta = readMetadata(file, getImage: true);
  final pic = meta.pictures.isNotEmpty ? meta.pictures.first : null;
  final stat = file.statSync();

  final fileName = p.basename(filePath);
  final title = (meta.title?.trim().isNotEmpty == true)
      ? meta.title!.trim()
      : p.basenameWithoutExtension(filePath);

  return ScannedSong(
    filePath: filePath,
    fileName: fileName,
    fileSize: stat.size,
    lastModifiedMs: stat.modified.millisecondsSinceEpoch,
    title: title,
    artist: _nullIfEmpty(meta.artist),
    albumArtist: _nullIfEmpty(meta.albumArtist),
    album: _nullIfEmpty(meta.album),
    trackNumber: meta.trackNumber,
    discNumber: meta.discNumber,
    durationMs: meta.duration?.inMilliseconds,
    year: _yearIfValid(meta.year),
    genre: meta.genres.isEmpty ? null : meta.genres.first,
    bitrate: meta.bitrate,
    sampleRate: meta.sampleRate,
    mimeType: mimeTypeForPath(filePath) ?? 'audio/unknown',
    pictureBytes: pic?.bytes,
    pictureMimeType: pic?.mimetype,
    hasEmbeddedArt: pic != null,
    hasEmbeddedLyrics: meta.lyrics != null && meta.lyrics!.trim().isNotEmpty,
    lyricsFilePath: _findLrcFile(filePath),
  );
}

/// 同步批量解析（单个 isolate 内顺序处理一个 chunk）。
List<_ParseOutcome> _parseBatch(List<String> paths) {
  final out = <_ParseOutcome>[];
  for (final path in paths) {
    try {
      out.add((path: path, song: _parseSync(path), failed: false));
    } catch (_) {
      // 具体异常由主 isolate 汇总时统一记 warning（isolate 内不调用 AppLogger，
      // 避免依赖 Flutter 框架的日志实现跨 isolate 出错）。
      out.add((path: path, song: null, failed: true));
    }
  }
  return out;
}

/// Looks for a `.lrc` file with the same base name as [audioPath].
///
/// Returns the path if found, or `null` otherwise.
String? _findLrcFile(String audioPath) {
  final dir = p.dirname(audioPath);
  final baseName = p.basenameWithoutExtension(audioPath);
  final lrcPath = p.join(dir, '$baseName.lrc');
  if (File(lrcPath).existsSync()) return lrcPath;
  // Also check uppercase extension (some files use .LRC)
  final lrcUpperPath = p.join(dir, '$baseName.LRC');
  if (File(lrcUpperPath).existsSync()) return lrcUpperPath;
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

/// 文件最后修改时间(epoch ms)；读取失败返回 0。
int _fileModifiedMsSync(String path) {
  try {
    return File(path).statSync().modified.millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}

