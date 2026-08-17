import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/m3u.dart';

/// M3U 导入结果。
class M3uImportResult {
  final List<Song> songs;

  /// M3U 中解析出的路径条目总数。
  final int total;

  const M3uImportResult({required this.songs, required this.total});

  /// 未匹配到库中歌曲的条目数。
  int get skipped => total - songs.length;
}

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

/// 从 [filePath] 导入 M3U/M3U8，按解析后的文件路径匹配库中歌曲。
Future<M3uImportResult> importM3uFromFile(String filePath) async {
  List<int> bytes;
  try {
    bytes = await File(filePath).readAsBytes();
  } catch (e, s) {
    AppLogger.error('M3U', 'Import failed: $filePath', e, s);
    rethrow;
  }
  // 容错解码：非法 UTF-8 字节替换为 U+FFFD，避免解析崩溃。
  final content = utf8.decode(bytes, allowMalformed: true);
  final rawPaths = parseM3u(content);
  final baseDir = p.dirname(filePath);

  final songs = <Song>[];
  for (final raw in rawPaths) {
    final resolved = resolveM3uPath(raw, baseDir);
    final song = await ServiceLocator.songRepo.getSongByFilePath(resolved);
    if (song != null) songs.add(song);
  }
  return M3uImportResult(songs: songs, total: rawPaths.length);
}
