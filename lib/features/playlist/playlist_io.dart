import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/services/service_locator.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/m3u.dart';
import '../../core/utils/m3u_match.dart';

/// 构建播放列表的 UTF-8 M3U8 字节内容（供 `file_picker` 的 `saveFile` 写入），
/// 返回 (字节内容, 歌曲数)。
///
/// 仅包含当前可用的歌曲（与播放列表现行语义一致）。
Future<({Uint8List bytes, int count})> buildPlaylistM3u8(int playlistId) async {
  final songs = await ServiceLocator.songRepo.getSongsInPlaylist(playlistId);
  final bytes = Uint8List.fromList(utf8.encode(buildM3u8(songs)));
  return (bytes: bytes, count: songs.length);
}

/// 把播放列表导出为 UTF-8 M3U8 写入 [filePath]，返回导出的歌曲数。
///
/// 仅导出当前可用的歌曲（与播放列表现行语义一致）。
Future<int> exportPlaylistToFile(int playlistId, String filePath) async {
  final songs = await ServiceLocator.songRepo.getSongsInPlaylist(playlistId);
  try {
    await File(filePath).writeAsString(buildM3u8(songs), encoding: utf8);
  } catch (e, s) {
    AppLogger.error('M3U', 'Export failed: $filePath', e, s);
    rethrow;
  }
  return songs.length;
}

/// 从 [filePath] 导入 M3U/M3U8，按「路径 → 名称 → 元数据」分级匹配库中歌曲。
///
/// 只为文件里的每条路径找出对应的**库中已有行**，不新增歌曲行、不改动文件。
/// 匹配规则见 `matchM3uEntries`：跨设备路径不同时靠文件名与标签命中。
Future<M3uMatchReport> importM3uFromFile(String filePath) async {
  List<int> bytes;
  try {
    bytes = await File(filePath).readAsBytes();
  } catch (e, s) {
    AppLogger.error('M3U', 'Import failed: $filePath', e, s);
    rethrow;
  }
  // 容错解码：非法 UTF-8 字节替换为 U+FFFD，避免解析崩溃。
  final content = utf8.decode(bytes, allowMalformed: true);
  final entries = parseM3u(content);

  // 一次取全库可用歌曲在内存建索引：替代逐条 SELECT，也顺带保证已删除文件
  // （is_available = 0）不会被导入。
  final library = await ServiceLocator.songRepo.getAvailableSongs();
  final report = matchM3uEntries(
    entries: entries,
    library: library,
    baseDir: p.dirname(filePath),
    homeDir: Platform.environment['HOME'],
  );

  AppLogger.info(
    'M3U',
    'Import matched ${report.matches.length}/${report.total}: '
        'path=${report.matchedByPath}, metadata=${report.matchedByMetadata}, '
        'duplicates=${report.duplicates}, skipped=${report.skipped}',
  );
  for (final match in report.matches) {
    // 非路径命中值得留痕：它能解释「为什么这首歌来自另一个路径」。
    if (match.tier == M3uMatchTier.path) continue;
    AppLogger.debug(
      'M3U',
      'Matched by ${match.tier.name}: ${match.entry.path} -> '
          '${match.song.filePath}',
    );
  }
  return report;
}
