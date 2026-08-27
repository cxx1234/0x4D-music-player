import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' show min;

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

import '../../models/scanned_song.dart';
import '../constants/mime_types.dart';
import '../utils/logger.dart';

/// Parses audio metadata from files using [audio_metadata_reader].
///
/// `audio_metadata_reader` 提供**同步**解析 API（`openSync` 读文件）。扫描由
/// UI isolate 触发，因此解析被包进 [Isolate.run] 在后台 isolate 执行，避免
/// 阻塞 UI。
///
/// 批量解析（[parseAll]）采用**受限并发 worker 池**：
/// - 并发数 = CPU 核数，钳制在 [1, _kMaxConcurrency]；
/// - 每个 worker 循环取下一个文件单独 [Isolate.run] 解析；
/// - 进度**节流推送**：worker 只累加计数，主 isolate 每 100ms 推送一次，
///   避免每个文件都触发 UI rebuild（400 次 -> ~10 次/秒）；
/// - 返回的 [ScannedSong] 是纯数据（含 Uint8List 封面），可跨 isolate 发送。
class MetadataService {
  /// 并发上限（多个 isolate 同时读大文件 + 封面，内存考虑）。
  static const int _kMaxConcurrency = 8;

  /// 进度节流间隔（毫秒）：避免每个文件都回调 UI，改为定时批量推送。
  /// 逐文件 SendPort 上报下，100ms 已足够平滑（10ms 会给 UI 过大压力）。
  static const int _kProgressIntervalMs = 100;

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
    final song = await _parseFileInIsolate(filePath);
    if (song != null) return song;
    AppLogger.warning('Scan', 'Failed to parse metadata: $filePath');
    return _fallbackSong(filePath);
  }

  /// Parses metadata for multiple files with bounded concurrency.
  ///
  /// 并发 worker 池：并发数 = CPU 核数（钳制 [1, _kMaxConcurrency]），每个
  /// worker 循环取下一个文件单独 [Isolate.run] 解析。进度**节流**：worker 只
  /// 累加计数，主 isolate 每 100ms 推送一次 [onProgress]，扫描期间不再逐文件
  /// 触发 UI rebuild。
  Future<(List<ScannedSong>, List<String>)> parseAll(
    List<String> filePaths, {
    void Function(int processed, int total, String currentFile)? onProgress,
  }) async {
    final total = filePaths.length;
    final failures = <String>[];
    if (total == 0) return (<ScannedSong>[], failures);

    // 并发数：CPU 核数，钳制在 [1, _kMaxConcurrency]。
    final concurrency = Platform.numberOfProcessors
        .clamp(1, _kMaxConcurrency)
        .toInt();

    // 批量 isolate + 逐文件进度：按并发数分 chunk，每 chunk 一个常驻 isolate
    // 顺序解析，并通过 SendPort 逐文件上报结果（isolate 数量 = 并发数，避免
    // 每文件 spawn 的 Flutter isolate 初始化开销；进度恢复逐文件平滑）。
    final chunkSize = (total / concurrency).ceil();
    final chunks = <List<String>>[];
    for (var i = 0; i < total; i += chunkSize) {
      chunks.add(filePaths.sublist(i, min(i + chunkSize, total)));
    }

    // 结果按下标填充（并发完成顺序无关）。
    final results = List<ScannedSong?>.filled(total, null);
    var done = 0;
    var lastFile = '';
    var lastReported = 0;

    // 进度节流：逐文件 done 累加（主 isolate 单线程，无竞态），每
    // _kProgressIntervalMs 推送一次，避免每个文件都触发 UI rebuild。
    final progressTimer = Timer.periodic(
      const Duration(milliseconds: _kProgressIntervalMs),
      (_) {
        if (done != lastReported) {
          lastReported = done;
          onProgress?.call(done, total, lastFile);
        }
      },
    );

    // ReceivePort 收集各 isolate 逐文件上报的结果与进度。
    final receivePort = ReceivePort();
    var pending = total;
    var portClosed = false;
    final doneCompleter = Completer<void>();
    receivePort.listen((msg) {
      final r = msg as _BatchMessage;
      pending--;
      if (r.song != null) {
        results[r.index] = r.song;
      } else {
        failures.add(r.path);
        AppLogger.warning('Scan', 'Failed to parse metadata: ${r.path}');
        results[r.index] = _fallbackSong(r.path);
      }
      done++;
      lastFile = p.basename(r.path);
      if (pending == 0) {
        portClosed = true;
        receivePort.close();
        if (!doneCompleter.isCompleted) doneCompleter.complete();
      }
    });

    try {
      for (var ci = 0; ci < chunks.length; ci++) {
        await Isolate.spawn(
          _batchWorker,
          (
            sendPort: receivePort.sendPort,
            paths: chunks[ci],
            startIndex: ci * chunkSize,
          ),
        );
      }
      await doneCompleter.future;
    } finally {
      progressTimer.cancel();
      if (!portClosed) receivePort.close();
    }

    // 收尾：确保最终进度回拨到 100%（最后一批可能不足一个节流周期）。
    onProgress?.call(total, total, lastFile);

    return (results.cast<ScannedSong>(), failures);
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

/// 在后台 isolate 解析单个文件；失败返回 null。
///
/// 必须是**顶层函数**：这样 [Isolate.run] 的闭包只捕获可发送的参数（String），
/// 不会携带外层作用域的不可发送对象（如 UI 进度回调 -> widget 树 ->
/// AsyncCompleter），避免抛 `Illegal argument in isolate message:
/// object is unsendable`。
/// 批量 isolate 的逐文件结果消息。
typedef _BatchMessage = ({int index, String path, ScannedSong? song});

/// isolate 入口：顺序解析一批文件，每完成一个通过 [SendPort] 逐文件上报，
/// 主 isolate 据此更新结果与进度。
///
/// [startIndex] 为 chunk 在原始文件列表中的起始下标，用于结果归位。
/// 失败文件以 song=null 上报，由主 isolate 汇总时降级处理。
void _batchWorker(
  ({SendPort sendPort, List<String> paths, int startIndex}) msg,
) {
  for (var i = 0; i < msg.paths.length; i++) {
    final path = msg.paths[i];
    try {
      msg.sendPort.send((
        index: msg.startIndex + i,
        path: path,
        song: _parseSync(path),
      ));
    } catch (_) {
      // 具体异常由主 isolate 汇总时统一记 warning（isolate 内不调用 AppLogger，
      // 避免依赖 Flutter 框架的日志实现跨 isolate 出错）。
      msg.sendPort.send((
        index: msg.startIndex + i,
        path: path,
        song: null,
      ));
    }
  }
}

/// 在后台 isolate 解析单个文件；失败返回 null。
///
/// 必须是**顶层函数**：这样 [Isolate.run] 的闭包只捕获可发送的参数（String），
/// 不会携带外层作用域的不可发送对象（如 UI 进度回调 -> widget 树 ->
/// AsyncCompleter），避免抛 `Illegal argument in isolate message:
/// object is unsendable`。
Future<ScannedSong?> _parseFileInIsolate(String filePath) async {
  try {
    return await Isolate.run(() => _parseSync(filePath));
  } catch (_) {
    return null;
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
